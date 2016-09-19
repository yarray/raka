require './dsl.rb'

dsl = DSL.new(self,
  output_types: [:table, :csv, :png, :pdf],
  input_types: [:table, :csv])

table.year_timespots = shell* 'echo $@.'
csv.year_timespots.round = shell* 'echo 42'

dsl.scopes :bw_de, :de

csv.simple_building = shell* 'echo 8080'
csv.simple_building.year = shell* 'echo 8081'

csv.building['(simple|compound)_building'].unit['year|quarter'].geom = [csv._('%{unit}_timespots').round] | shell* %(
    echo %{building}
    echo %{building0}
    echo $(scope).$(stem)
)

# _.fact.func['percent_(\S+)'] = r %(
#     sql_input('SELECT timespot, %{func0}/total::float FROM $^', #{RCONN_ARGS}) | csv_output($@)
# )

# rule(/geom__(?<unit>(year|quarter))__(?<building>(?<building0>(simple|compound))_building)/ => [proc { |target|
#     # deps.map do |templ|
#     #     templ.to_s % captures_hash
#     # end
#     []
# }]) do |task|
#     # action.code = fulfill_args action.code, task, captures(task.target)
#     # action.run
#     puts 'hello'
# end
#
# task 'geom__year__simple_building' do
#     puts 'Hello'
# end
