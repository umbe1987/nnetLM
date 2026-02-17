new_nnetLM <- function(x, ..., class = character()) {
  structure(x, class = "nnetLM")
}

validate_nnetLM <- function(x) {
  if (!inherits(x, "nnetLM")) {
    stop(
      "Not a valid `nnetLM` object"
    )
  }
  x
}

#' Initalize the neural network object
#'
#' @param X Matrix of independent variables
#' @param y Vector of dependent variables
#' @param hidden Vector of number of nodes in each hidden layer
#' @param actFn List of activation functions (must be length(hidden)+1 for the output node)
#' @details
#' The activation functions within [actFn] list can be any existing or user-defined
#' function. They must have a single numeric argument (e.g. [x]), and must return
#'  a numeric value of the same length as [x].
#' @returns An object with S3 class "nnetLM"
#' @examples
#' set.seed(123)
#' x <- seq(-10, 10, by = 0.1)
#' y <- sin(x) + rnorm(length(x), mean = 0, sd = 0.1)
#' X <- matrix(x, nrow = length(x), ncol = 1)
#' hidden <- c(10)
#' linear <- function(x) x
#' actFn <- list(tanh, linear)
#' nnet.obj <- nnetLM(X, y, hidden, actFn)
#' @export
nnetLM <- function(X, y, hidden, actFn) {
  # prepend the nodes to account for the input layer
  hidden <- c(ncol(X), hidden, 1)
  # Generate weights and biases
  W <- vector(mode = "list", length = length(hidden) - 1)
  b <- vector(mode = "numeric", length = length(hidden) - 1)
  for (i in 1:(length(hidden) - 1)) {
    W[[i]] <- matrix(stats::runif(hidden[i] * hidden[i + 1], -1, 1), nrow = hidden[i + 1], ncol = hidden[i])
    b[[i]] <- 1
  }
  res <- list(X = X, y = y, W = W, b = b, hidden = hidden, actFn = actFn, par = NULL)
  validate_nnetLM(new_nnetLM(res))
}

#' Performs a forward pass
#'
#' @param object a trained network object of class "nnetLM"
#' @param newdata Matrix of predictors
#' @returns a numeric vector with predicted values
#' @seealso [flatten_params()]
#' @examples
#' set.seed(123)
#' x <- seq(-10, 10, by = 0.1)
#' y <- sin(x) + rnorm(length(x), mean = 0, sd = 0.1)
#' X <- matrix(x, nrow = length(x), ncol = 1)
#' hidden <- c(10)
#' linear <- function(x) x
#' actFn <- list(tanh, linear)
#' nnet.obj <- nnetLM(X, y, hidden, actFn)
#' nnet.obj$par <- nnetLM:::flatten_params(nnet.obj)
#' pred.nnetLM <- predict(nnet.obj, X)
#' @exportS3Method stats::predict
predict.nnetLM <- function(object, newdata) {
  if (is.null(object$par)) {
    stop("Please train the network with train.nnetLM before passing it to predict.nnetLM")
  }
  upar <- unflatten_params(object$par, object)
  outputs <- lapply(1:nrow(newdata), function(i) {
    out.i <- newdata[i, , drop = FALSE]
    for (j in 1:(length(object$hidden) - 1)) {
      fn <- object$actFn[[j]] # J-th activation function
      out.i <- tcrossprod(out.i,upar$W[[j]]) + upar$b[j]
      out.i <- fn(out.i)
    }
    return(out.i)
  })
  return(unlist(outputs))
}

#' Flattens the network parameters so they can be passed to [minipack.lm::nls.lm]
#' 'par' argument
#'
#' @param object an object of class "nnetLM"
#' @returns flattened vector with network parameters (weights and biases)
flatten_params <- function(object) {
  params <- c(unlist(object$W), object$b)
  return(params)
}


#' Unflattens the network parameters after they have been used by [minipack.lm::nls.lm]
#'
#' @param params vector of flattened network parameters (weights and biases)
#' @param object an object of class "nnetLM"
#' @returns unflattened list with network parameters (weights and biases)
unflatten_params <- function(params, object) {
  hidden <- object$hidden
  i <- 1
  W <- vector(mode = "list", length = length(hidden) - 1)
  b <- numeric(length(hidden) - 1)
  for (j in 1:(length(hidden) - 1)) {
    W[[j]] <- matrix(params[i:(i + hidden[j] * hidden[j + 1] - 1)], nrow = hidden[j + 1], ncol = hidden[j], byrow = FALSE)
    i <- i + hidden[j] * hidden[j + 1]
  }
  for (j in 1:(length(hidden) - 1)) {
    b[j] <- params[i]
    i <- i + 1
  }
  return(list(W = W, b = b))
}

#' Residual function needed by [minipack.lm::nls.lm]
#'
#' @param params vector of flattened network parameters (weights and biases)
#' @param observed an object of class "nnetLM"
#' @param object an object of class "nnetLM"
#' @param xx an object of class "nnetLM"
#' @returns unflattened list with network parameters (weights and biases)
#' @seealso [flatten_params()]
residFun <- function(params, observed, object, xx) {
  object$par <- params
  observed - predict.nnetLM(object, xx)
}

#' Train the neural network with Levenberg-Marquardt optimization
#' using [minipack.lm::nls.lm]
#'
#' @param object an object of class "nnetLM"
#' @param epochs maximum number of iteration
#' @param progress flag for printing network progress. Default is FALSE
#' @returns the trained network object
#' @seealso [minipack.lm::nls.lm()]
#' @import minpack.lm
#' @export
train.nnetLM <- function(object, epochs, progress = FALSE) {
  parStart <- flatten_params(object)
  # perform fit
  nls.lm.out <-
    nls.lm(
      par = parStart, fn = residFun, observed = object$y,
      xx = object$X, object = object,
      control = nls.lm.control(maxiter = epochs, nprint = ifelse(progress, 1, 0))
    )
  upar <- unflatten_params(nls.lm.out$par, object)
  object$W <- upar$W
  object$b <- upar$b
  object$par <- nls.lm.out$par

  return(object)
}
