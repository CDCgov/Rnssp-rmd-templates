return_longterm_query <- function(url, profile, loop_start, loop_end, by = 15) {
  
  #### Setup for loop ####
  # function to create a data frame with the start and end dates you are trying to use 
  # default is 14 day intervals, but you can specify any number of days in the by argument when you call the function 
  loop_start <- as.Date(loop_start)
  loop_end <- as.Date(loop_end)
  
  loop_dates <- data.frame(start = seq.Date(from = loop_start, to = loop_end, by = by)
                           # ,end = rev(seq.Date(from = loop_end, to = loop_start, by = -1*by))
  ) %>%
    mutate(end = start+(by-1)) %>%
    mutate(end = ifelse((loop_end>start&end>loop_end),loop_end,end)) %>%
    mutate(end = as.Date.numeric(end, origin = "1970-01-01"))
  
  # initiate a blank list to store the output from the loop
  output_list <- list()
  
  #### Loop over multiple time frames ####
  # loop to change the dates, get csv from url, and store output in a list
  cli_progress_bar("Receiving data by chunks...", total = nrow(loop_dates))
  for (i in 1:nrow(loop_dates)) {
    
    # update the to the i set of start and end dates in the url
    url_update <- change_dates(url, start_date = loop_dates$start[i], end_date = loop_dates$end[i])
    # generate the output from the i set of start and end dates
    new_output <- try(profile$get_api_data(url = url_update, fromCSV = TRUE, show_col_types = FALSE) %>%
                        mutate_all(as.character), silent = TRUE)
    # store the results from the i set of start and end dates as the i element in a list
    if(all(class(new_output) == "try-error")){
      cli_alert(paste0("Data pull unsuccessful - skipped: ", loop_dates$start[i], " to ", loop_dates$end[i]))
    } else {
      output_list[[i]] <- new_output
    }
    cli_progress_update()
  }
  
  #### Result ####
  # collapse results of the list generated in the output above into a data frame
  all_data <- bind_rows(output_list)
  
  return(all_data)
  
}
