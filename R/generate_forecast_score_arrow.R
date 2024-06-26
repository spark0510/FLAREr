#' Score a forecast using score4cast package and arrow
#' @param targets_file observation file
#' @param forecast_df forecast file
#' @output_directory directory to save scored file
#' @return
#' @export
#'
#' @examples
generate_forecast_score_arrow <- function(targets_file,
                                          forecast_df,
                                          use_s3 = FALSE,
                                          server_name = NULL,
                                          folder = NULL,
                                          #bucket = NULL,
                                          #endpoint = NULL,
                                          local_directory = NULL,
                                          variable_types = "state"){


  if(use_s3){
    if(is.null(server_name) | is.null(folder)){
      stop("scoring function needs bucket and endpoint if use_s3=TRUE")
    }
    #vars <- arrow_env_vars()
    #output_directory <- arrow::s3_bucket(bucket = bucket,
    #                                     endpoint_override =  endpoint)
    output_directory <- FaaSr::faasr_arrow_s3_bucket(server_name=server_name, 
                                                     faasr_prefix=folder)
    #unset_arrow_vars(vars)
  }else{
    if(is.null(local_directory)){
      stop("scoring function needs local_directory if use_s3=FALSE")
    }
    output_directory <- arrow::SubTreeFileSystem$create(local_directory)
  }


  target <- readr::read_csv(targets_file, show_col_types = FALSE)

  if("time" %in% colnames(target)){
    target <- target |>
      dplyr::rename(datetime = time)
  }

  if("pub_time" %in% colnames(forecast_df)){
    forecast_df <- forecast_df |>
      dplyr::rename(pub_datetime = pub_time)
  }

  if("pubDate" %in% colnames(forecast_df)){
    forecast_df <- forecast_df |>
      dplyr::rename(pub_datetime = pubDate)
  }

  df <- forecast_df %>%
    dplyr::filter(variable_type %in% variable_types) |>
    dplyr::mutate(family = as.character(family)) |>
    score4cast::crps_logs_score(target, extra_groups = c('depth')) |>
    dplyr::mutate(horizon = datetime-lubridate::as_datetime(reference_datetime)) |>
    dplyr::mutate(horizon = as.numeric(lubridate::as.duration(horizon),
                                units = "seconds"),
           horizon = horizon / 86400)

  df <- df |> dplyr::mutate(reference_date = lubridate::as_date(reference_datetime))

  arrow::write_dataset(df, path = output_directory, partitioning = c("site_id","model_id","reference_date"))

}
