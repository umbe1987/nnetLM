# activation functions
sigmoid <- function(x) 1 / (1 + exp(-x))
dsigmoid <- function(x) sigmoid(x) * (1 - sigmoid(x))
relu <- function(x) x * (x > 0)
drelu <- function(x) 1 * (x > 0)
linear <- function(x) x
dlinear <- function(x) 1
dtanh <- function(x) 1 - x^2

# error metrics
mape <- function(observed, predicted) mean(abs((observed - predicted) / observed)) * 100
