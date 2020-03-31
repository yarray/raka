suppressPackageStartupMessages(library(RPostgreSQL))
suppressPackageStartupMessages(library(ggplot2))
suppressPackageStartupMessages(library(gridExtra))

# input
# -----
file_input <- function(fileName, coltypes = NA) {
    read.table(fileName, header = T, sep = ',', colClasses = coltypes)
}

join_file_input <- function(namesstr, key) {
    files <- strsplit(namesstr, split = '\\+')[[1]]
    dataList <- lapply(files, (function(f) fileInput(f)))
    do.call(merge, c(dataList, by = key))
}

init_table_input <- function(conn_args, schema) {
    function(name, cols = '*', where = 'true') {
        colstr <- paste(cols, collapse = ',')

        sql <- sprintf("SELECT %s FROM %s WHERE %s", colstr, name, where)
        init_sql_input(conn_args, schema)(sql)
    }
}

init_sql_input <- function(conn_args, schema) {
    function(sql) {
        conn <- do.call(dbConnect, c(dbDriver('PostgreSQL'), conn_args))
        on.exit(dbDisconnect(conn))
        dbGetQuery(conn, paste('SET search_path TO', paste(c(schema, 'public'), sep = ',')))
        buffer <- dbSendQuery(conn, sql)
        fetch(buffer, n=-1)
    }
}

create_parents <- function(output) {
    dir.create(dirname(output), showWarnings = FALSE, recursive = TRUE)
}

# Output
# ------
# TODO consider deprecating this, perhaps more specific ones like graph_output is still useful
auto_output <- function(report, ...) {
    actual <- switch(class(report)[1],
                     gg = ggplot_output,
                     data.frame = csv_output,
                     print)
    actual(report, ...)
}

rplot_output <- function(f, output, size = c(8, 8)) {
    create_parents(output)
    size <- ceiling(size / 2.54 * 300 / 96) # convert cm to inch
    par(mar = c(0,0,0,0))
    # use pdf since png can be very weird, e.g. radarplot
    pdf(output, width = size[1], height = size[2], pointsize = 12)
    f()
    dev.off()
}

# use facet or latex subfigure, do not handle list anymore
ggplot_output <- function(report, output, size = c(15, 15), fontScale = 1, compact = F) {
    create_parents(output)
    if (compact) {
        margin <- 1
    } else {
        margin <- 5
    }

    report <- report + theme_bw() +
        theme(axis.title = element_text(size = 13 * fontScale),
              axis.text = element_text(size = 11 * fontScale),
              legend.title = element_text(size = 13 * fontScale),
              legend.text = element_text(size = 11 * fontScale),
              legend.key.size = unit(13 * fontScale, 'pt'),
              legend.margin = unit(0, "cm"),
              legend.background = element_rect(fill = alpha('white', 0)),
              plot.margin = unit(c(margin, margin, 0, 0),"mm"))

    width <- size[1]
    height <- size[2]

    ggsave(report, filename = output,
           dpi = 300, units = 'cm', width = width, height = height, limitsize = FALSE)
}

csv_output <- function(report, output) {
    create_parents(output)
    write.table(format(report, digits = 4), file = toString(output), row.names = FALSE,
                sep = ',', quote = FALSE)
}

txt_output <- function(report, output) {
    create_parents(output)
    write.table(format(report, digits = 4), file = toString(output), row.names = FALSE,
                sep = ',', quote = FALSE)
}

init_table_output <- function(conn_args, schema) {
    function(report, output, placeholder = NULL) {
        conn <- do.call(dbConnect, c(dbDriver('PostgreSQL'), conn_args))
        on.exit(dbDisconnect(conn))
        dbGetQuery(conn, paste('SET search_path TO', paste(c(schema, 'public'), sep = ',')))

        if (dbExistsTable(conn, output)) {
            dbRemoveTable(conn, output)
        }
        dbWriteTable(conn, output, report, row.names = F)
        if (!is.null(placeholder)) {
            write.table(data.frame(), file = placeholder, col.names = FALSE)
        }
    }
}
