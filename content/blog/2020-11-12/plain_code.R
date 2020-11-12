library(tidyverse)
library(googlesheets4)
library(rmarkdown)

# read in all of the responses
responses <-
  read_sheet(
    "https://docs.google.com/spreadsheets/d/1saowcRmK3S4mUO5qOuDT_WQycNtGG1_eSYpETodzePw/edit?usp=sharing"
  )

responses

# split up the dataframe by presenter
responses_list <- 
  responses %>%
  group_split(presenter)

responses_list[[1]]

# collates responses from the dataframe for a given presenter into
# lines of a .md file
write_feedback_lines <- function(presenter_df) {
  out <- 
    paste0("# ", presenter_df$presenter[1]) %>%
    c("") %>%
    c("### Summaries of Main Argument") %>%
    c(paste0("* ", presenter_df$main_argument)) %>%
    c("") %>%
    c("### Additional Comments") %>%
    c(paste0("* ", presenter_df$additional_feedback))
  
  out
}

# check output for first entry
write_feedback_lines(responses_list[[1]])

# make a vector of lines out of each data subset
presenter_lines <-
  map(
    responses_list,
    write_feedback_lines
  ) %>%
  # set the names of the object to the presenter's name
  set_names(
    map(
      responses_list, 
      pluck, 
      "presenter", 
      1
    )
  )

# path to the directory you'd like to write to
folder <- "feedback/"

map2(
  # the lines for each presenter
  presenter_lines,
  # the path to write the lines to for the presenter
  paste0(folder, names(presenter_lines), ".md"),
  # the function to use to write the lines
  write_lines
)

# check out the files in the folder
list.files(folder)

# create the .pdf files
map(
  paste0(folder, names(presenter_lines), ".md"),
  rmarkdown::render,
  "pdf_document"
)

# delete the source .md files
files <- list.files(folder, full.names = TRUE)
mds <- files[str_detect(files, ".md")]
file.remove(mds)

# check out the files in the folder
list.files(folder)