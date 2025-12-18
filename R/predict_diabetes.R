#' Predict Diabetes Risk (Core Function)
#'
#' @description
#' A production-ready inference function that predicts diabetes risk using a pre-trained
#' Random Forest classifier. This function implements an automated preprocessing pipeline
#' that maps raw input values (numeric or character) to the specific factor levels and
#' ordered schemas required by the training data, ensuring robust execution against
#' diverse input formats.
#'
#' @param input_data A data.frame containing patient health indicators.
#'   Must include the following columns: \code{HighChol}, \code{HighBP}, \code{DiffWalk},
#'   \code{Age}, \code{GenHlth}, \code{BMI}, \code{HvyAlcoholConsump}, \code{CholCheck}.
#'   Accepts raw numeric codes (e.g., 1-13 for Age) or character labels.
#' @param model_path (Optional) A character string specifying the path to a custom
#'   \code{.rds} model file. If \code{NULL} (default), the function dynamically loads
#'   the internal model artifact shipped with the package.
#'
#' @return A character vector indicating the prediction result: "Yes" (High Risk) or "No" (Low Risk).
#'
#' @import randomForest
#' @importFrom stats predict
#' @export
#'
#' @examples
#' # 1. Retrieve the sample dataset included in the package
#' data_path <- system.file("extdata", "sample.csv", package = "DiabetesPredictor")
#' input_data <- read.csv(data_path)
#'
#' # 2. Execute prediction
#' # The function automatically handles type conversion and model loading
#' predictions <- predict_diabetes(input_data)
#' print(predictions)
predict_diabetes <- function(input_data, model_path = NULL) {

  # =========================================================================
  # Phase 1: Resource Initialization
  # =========================================================================

  # Resolve model path: Use dependency injection if provided, otherwise fallback
  # to the internal serialized model artifact located in inst/extdata.
  if (is.null(model_path)) {
    model_path <- system.file("extdata", "rf_model.rds", package = "DiabetesPredictor")
  }

  # Validate model file existence to prevent downstream runtime errors
  if (model_path == "") {
    stop("Configuration Error: 'rf_model.rds' not found in package installation directory.")
  }

  # Load the serialized Random Forest object
  rf_model <- readRDS(model_path)

  # =========================================================================
  # Phase 2: Schema Alignment & Input Sanitization
  # =========================================================================
  # Create a local copy to perform transformations without side effects on input
  df <- input_data

  # 2.1 Binary Feature Mapping
  # standardize raw inputs (0/1 or "Yes"/"No") to strict factor levels c("No", "Yes")
  binary_cols <- c("HighChol", "HighBP", "DiffWalk", "HvyAlcoholConsump", "CholCheck")

  for (col in binary_cols) {
    if (col %in% names(df)) {
      # Logic: explicitly map 1 or "Yes" to "Yes", everything else to "No"
      df[[col]] <- factor(ifelse(df[[col]] == 1 | df[[col]] == "Yes", "Yes", "No"),
                          levels = c("No", "Yes"))
    }
  }

  # 2.2 Ordinal Encoding: General Health
  # Enforce ordered factor structure: 1 (Excellent) -> 5 (Poor)
  if ("GenHlth" %in% names(df)) {
    df$GenHlth <- factor(df$GenHlth,
                         levels = 1:5,
                         labels = c("Excellent", "Very Good", "Good", "Fair", "Poor"),
                         ordered = TRUE)
  }

  # 2.3 Ordinal Encoding: Age Group
  # Map numeric bins (1-13) to specific age ranges required by the model
  if ("Age" %in% names(df)) {
    df$Age <- factor(df$Age,
                     levels = 1:13,
                     labels = c("18-24", "25-29", "30-34", "35-39", "40-44", "45-49",
                                "50-54", "55-59", "60-64", "65-69", "70-74", "75-79", "80+"),
                     ordered = TRUE)
  }

  # =========================================================================
  # Phase 3: Inference Execution
  # =========================================================================

  # Validation: Ensure continuous variable existence
  if (!"BMI" %in% names(df)) {
    stop("Input Validation Error: Missing required column 'BMI'.")
  }

  # Execute prediction with error handling wrapper
  tryCatch({
    prediction <- predict(rf_model, df, type = "response")
    return(as.character(prediction))
  }, error = function(e) {
    # Propagate a descriptive error message for debugging
    stop(paste("Inference Failed: Unable to generate predictions. Cause:", e$message))
  })
}
