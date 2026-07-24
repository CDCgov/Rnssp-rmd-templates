
# Chunk pull in parallel
chunk_pull <- function(
    url,
    start_date,
    end_date,
    by = 15,
    attempts = 5,
    profile = myProfile,
    workers = NULL,
    retry_sleep = 5,
    ...
) {
  if (!requireNamespace("future", quietly = TRUE) ||
      !requireNamespace("future.apply", quietly = TRUE)) {
    stop("Please install packages 'future' and 'future.apply' to use parallel chunk pulls.")
  }
  
  loop_start <- as.Date(start_date)
  loop_end <- as.Date(end_date)
  
  if (is.na(loop_start) || is.na(loop_end)) stop("'start_date' and 'end_date' must be valid dates.")
  by <- as.integer(by)
  attempts <- as.integer(attempts)
  retry_sleep <- as.numeric(retry_sleep)
  
  if (is.null(workers)) {
    workers <- max(1L, as.integer(future::availableCores()) - 1L)
  }
  workers <- as.integer(workers)
  
  if (by < 1L) stop("'by' must be >= 1.")
  if (attempts < 1L) stop("'attempts' must be >= 1.")
  if (workers < 1L) stop("'workers' must be >= 1.")
  if (is.na(retry_sleep) || retry_sleep < 0) stop("'retry_sleep' must be >= 0.")
  if (loop_start > loop_end) return(dplyr::bind_rows(list()))
  
  chunk_starts <- seq.Date(from = loop_start, to = loop_end, by = by)
  chunk_ends <- pmin(chunk_starts + (by - 1L), loop_end)
  n_chunks <- length(chunk_starts)
  dots <- list(...)
  
  cli::cli_alert_info("Pulling {n_chunks} chunks in parallel using {workers} workers.")
  
  old_plan <- future::plan()
  on.exit(future::plan(old_plan), add = TRUE)
  future::plan(future::multisession, workers = workers)
  
  harmonize_chunk_types <- function(df_list) {
    all_cols <- unique(unlist(lapply(df_list, names), use.names = FALSE))
    
    # Ensure every chunk has the same columns and order
    df_list <- lapply(df_list, function(df) {
      missing_cols <- setdiff(all_cols, names(df))
      if (length(missing_cols) > 0L) {
        for (col in missing_cols) df[[col]] <- NA
      }
      df[all_cols]
    })
    
    # Cast each column to a common type; fallback to character when incompatible
    for (col in all_cols) {
      col_vals <- lapply(df_list, function(df) df[[col]])
      ptype <- try(do.call(vctrs::vec_ptype_common, col_vals), silent = TRUE)
      
      if (inherits(ptype, "try-error")) {
        cli::cli_alert_warning(
          "Column {col} has incompatible types across chunks; coercing to character."
        )
        df_list <- lapply(df_list, function(df) {
          df[[col]] <- as.character(df[[col]])
          df
        })
      } else {
        df_list <- lapply(df_list, function(df) {
          df[[col]] <- vctrs::vec_cast(df[[col]], ptype)
          df
        })
      }
    }
    
    df_list
  }
  
  pull_one_chunk <- function(i) {
    url_update <- change_dates(
      url,
      start_date = chunk_starts[i],
      end_date = chunk_ends[i]
    )
    
    result <- NULL
    warning_msgs <- character(0)
    
    for (attempt in seq_len(attempts)) {
      result <- try(
        do.call(
          get_essence_data,
          c(list(url = url_update, profile = profile), dots)
        ),
        silent = TRUE
      )
      
      if (!inherits(result, "try-error")) {
        return(list(data = result, warnings = warning_msgs, error = NULL))
      }
      
      if (attempt < attempts) {
        warning_msgs <- c(
          warning_msgs,
          sprintf(
            "Data pull unsuccessful - retrying chunk %d/%d (attempt %d/%d)",
            i, n_chunks, attempt + 1L, attempts
          )
        )
        Sys.sleep(retry_sleep)
      }
    }
    
    list(
      data = NULL,
      warnings = warning_msgs,
      error = sprintf(
        "Data pull unsuccessful after %d attempts - skipped: %s to %s",
        attempts,
        as.character(chunk_starts[i]),
        as.character(chunk_ends[i])
      )
    )
  }
  
  results <- future.apply::future_lapply(
    X = seq_len(n_chunks),
    FUN = pull_one_chunk,
    future.seed = TRUE
  )
  
  output_list <- vector("list", n_chunks)
  for (i in seq_len(n_chunks)) {
    res <- results[[i]]
    
    if (length(res$warnings) > 0L) {
      for (msg in res$warnings) cli::cli_alert_warning(msg)
    }
    
    if (!is.null(res$error)) {
      cli::cli_alert_danger(res$error)
    } else {
      output_list[[i]] <- res$data
    }
  }
  
  output_list <- output_list[!vapply(output_list, is.null, logical(1))]
  if (length(output_list) == 0L) return(dplyr::bind_rows(list()))
  
  output_list <- lapply(output_list, function(df) {
    if ("C_Patient_Age" %in% names(df)) {
      df$C_Patient_Age <- suppressWarnings(as.numeric(as.character(df$C_Patient_Age)))
    }
    df
  })
  
  output_list <- harmonize_chunk_types(output_list)
  dplyr::bind_rows(output_list)
}
