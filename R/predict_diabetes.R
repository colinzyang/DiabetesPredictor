#' Predict Diabetes Risk (Core Function)
#'
#' @description
#' A robust wrapper function that predicts diabetes risk. It automatically loads the
#' internal Random Forest model and sanitizes input data (converting numeric codes
#' to factors) to match the strict schema required by the training data.
#'
#' @param input_data A data.frame containing patient vitals. Required columns:
#'   HighChol, HighBP, DiffWalk, Age, GenHlth, BMI, HvyAlcoholConsump, CholCheck.
#'   (Accepts raw numeric inputs like 0/1 or 1-13 for Age).
#' @param model_path (Optional) Path to the .rds model file. Defaults to the internal package model.
#'
#' @return A character vector: "Yes" (High Risk) or "No" (Low Risk).
#' @import randomForest
#' @importFrom stats predict
#' @export
#'
#' @examples
#' # 1. Load the internal example data
#' data_path <- system.file("extdata", "sample.csv", package = "DiabetesPredictor")
#' my_data <- read.csv(data_path)
#'
#' # 2. Make a prediction
#' predict_diabetes(my_data)
predict_diabetes <- function(input_data, model_path = NULL) {

  # --- 1. Load Model (Singleton Pattern) ---
  if(is.null(model_path)) {
    # 按照 Practical 7 要求，使用 system.file 定位 inst/extdata 下的文件
    model_path <- system.file("extdata", "rf_model.rds", package = "DiabetesPredictor")
  }

  if(model_path == "") {
    stop("Model file not found. Please ensure 'rf_model.rds' is in inst/extdata/")
  }

  rf_model <- readRDS(model_path)

  # --- 2. Data Engineering (Hard-coded Preprocessing) ---
  # 复刻队友 Rmd 中的数据清洗逻辑，防止 User 输入数字导致报错

  df <- input_data

  # 2.1 二分类变量转换 (0/1 -> No/Yes)
  binary_cols <- c("HighChol", "HighBP", "DiffWalk", "HvyAlcoholConsump", "CholCheck")
  for(col in binary_cols) {
    if(col %in% names(df)) {
      # 强制转为 factor，并对齐 levels
      df[[col]] <- factor(ifelse(df[[col]] == 1 | df[[col]] == "Yes", "Yes", "No"),
                          levels = c("No", "Yes"))
    }
  }

  # 2.2 有序变量: GenHlth (1-5)
  if("GenHlth" %in% names(df)) {
    df$GenHlth <- factor(df$GenHlth, levels = 1:5,
                         labels = c("Excellent", "Very Good", "Good", "Fair", "Poor"),
                         ordered = TRUE)
  }

  # 2.3 有序变量: Age (1-13)
  if("Age" %in% names(df)) {
    df$Age <- factor(df$Age, levels = 1:13,
                     labels = c("18-24", "25-29", "30-34", "35-39", "40-44", "45-49",
                                "50-54", "55-59", "60-64", "65-69", "70-74", "75-79", "80+"),
                     ordered = TRUE)
  }

  # --- 3. Prediction ---
  # 确保 BMI 存在
  if(!"BMI" %in% names(df)) stop("Missing column: BMI")

  tryCatch({
    prediction <- predict(rf_model, df, type = "response")
    return(as.character(prediction))
  }, error = function(e) {
    stop(paste("Prediction failed. Check input data types.", e$message))
  })
}
