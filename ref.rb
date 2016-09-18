require 'securerandom'
require 'rake'

# task extensions
# ---------------
def match(spec)
    pattern = Regexp.new spec.keys.first.to_s
    
    rule(pattern => [proc { |tname|
        captures = pattern.match(tname).captures
        captures_hash = Hash[((0 .. captures.length - 1).map {|x| x.to_s.to_sym }).zip(captures)]
        spec.values.flatten.map do |templ|
            templ.to_s % captures_hash
        end
    }]) do |t|
        class << t
            attr_accessor :captures
            attr_accessor :capture
        end
        t.captures = pattern.match(t.name).captures
        t.capture = t.captures.first
        yield t 
    end 
end

# shortcut
class Rake::Task
    def deps
        return prerequisites
    end

    def dep
        return prerequisites.first
    end
end

# runner
# ------
def create_tmp(content)
    tmpfile = "/tmp/#{SecureRandom.uuid}"

    File.open(tmpfile, 'w') do |f|
        f.write content
    end
    
    return tmpfile
end

def gen_r_code(deps, code)
    libraries = [
        :pipeR,
    ].map { |name| "suppressPackageStartupMessages(library(#{name}))" }

    sources = ([
        :io,
    ] + deps).map { |name| "source('src/#{name}.R')" }

    extra = [
        '`|` <- `%>>%`',
    ]

    [libraries, sources, extra, code].join("\n")
end

# runners
def R(deps, code)
    puts code
    sh "Rscript #{create_tmp(gen_r_code(deps, code))}"
end

def bash(orig_cmd)
    cmd = %{
    set -e #{orig_cmd}
    }

    sh cmd
end

def psql(runner, cmd)
    puts cmd
    sh "#{runner} -f #{create_tmp(cmd)}"
end

def psql_withf(conn_str, tname, fname, params)
    matched = tname.match(/^(\S+)\./)
    if matched
        search_path = matched[1] + ',public'
    else
        search_path = :public
    end

    parstr = params.reduce('') { |cur, (k, v)| %{#{cur} -v #{k}="#{v}"} }
    bash %{
        psql "#{conn_str} options='--search_path=#{search_path}'" -v ON_ERROR_STOP=1 -f src/#{fname}.sql -v tname=#{tname} #{parstr}
        touch #{tname}
    }
end

def psqlf(conn_str, tname, params)
    matched = tname.match(/\.(\S+)$/)
    if matched
        table = matched[1]
    else
        table = tname
    end
    psql_withf(conn_str, tname, table, params)
end
