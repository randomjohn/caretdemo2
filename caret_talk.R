# caret talk for Upstate Analytics
# John Johnson
# March ?, 2015

library(caret)
library(doParallel)

cl <- makeCluster(2)
registerDoParallel(cl)
# get data ----------------------------------------------------------------



har.data <- read.table("dataset-har-PUC-Rio-ugulino.csv",
                       header=TRUE,
                       stringsAsFactors=TRUE,
                       sep=';',
                       dec=',')

# data cleaning -----------------------------------------------------------

extract.features <- function(df) {
  return(df[,-1])
}

# we only have one dataset here, so I didn't really need to write the function above
# but often, datasets will come as a train and a test, and the function
# comes in very handy. Here, our dataset is pretty good.

# har.data <- extract.features(har.data)


# data partition ----------------------------------------------------------

# create a hold-out dataset
set.seed(3878)
intrain <- createDataPartition(har.data$class,p=0.7)[[1]]
train.set <- har.data[intrain,]
val.set <- har.data[-intrain,]


# exploratory data analysis -----------------------------------------------

# it is important that we make *all* of our decisions about data --
# variable selection, transformations, etc. on our training set
# we must not use any of the hold-out validation data for these or
# else we could be severely biased

# looking at actual data is never a bad idea
head(train.set,10)
tail(train.set,10)
View(har.data)

# univariate analysis of the x, y, and z variables
# this is just quick and dirty
# most people would use ggplot2 these days for this kind of work
op <- par(mfrow=c(3,3))
for (i in c("x","y","z")) {
  for (j in 1:3) {
    hist(train.set[,paste0(i,j)],main="",xlab=paste0(i,j))  }
}
par(op)
# note the skewness of the x2, y2, and z2 variables
# look at skewness measure (third central moment) to determine transformations
# this is an example of some of the things to review

library(e1071) # for skewness
xyzvars <- paste0(c("x","y","z"),rep(1:3,each=3))
# make a table with the mean, sd, skewness
# note: I'd normally do this with dplyr
cbind(mean=apply(train.set[,xyzvars],2,mean),
      sd=apply(train.set[,xyzvars],2,sd),
      skew=apply(train.set[,xyzvars],2,skewness),
      perc.miss=apply(train.set[,xyzvars],2,function(x) 100*sum(is.na(x)/length(x))))


# now we look for "near zero variance" variables. These are ones that
# are mostly one value (or missing). They add no value to predictive models
# and cause most ML algorithms to fail.
nearZeroVar(train.set,saveMetrics=TRUE,allowParallel=TRUE)
table(train.set$class)

# featurePlot is a caret function
featurePlot(train.set[,paste0(c("x","y","z"),2)],train.set$class,"pairs")
featurePlot(train.set[,paste0(c("x","y","z"),2)],train.set$class,"ellipse")
# this is not everything that can be done -- I didn't include height and weight vars

# doing skewness on height, weight, and body_mass_index is a little tricker
# these are subject characteristics, so we can't just apply to the whole dataset
# therefore, I put this into a subject-level dataset
library(dplyr)
subs.only  <- train.set %>%
  group_by(user) %>%
  select(one_of(c("user","gender","age","how_tall_in_meters","weight","body_mass_index"))) %>%
  distinct()
subs.only
# note that BMI = weight / how_tall_in_meters^2
# it's not clear that we really have enough variation in these variables to
# do a lot of good with transformations.
# in a linear model, you would analyze this as a split-plot design 
# (i.e. all other variables nested within these subject-level variables)
# or a mixed model

# preprocessing -----------------------------------------------------------



# we'll explore a Box-Cox on these variables
for (i in c("x","y","z")) {
  for (j in 1:3) {
        cat(paste0(i,j),'\n')
        print(BoxCoxTrans(train.set[,paste0(i,j)] ))
  }
}
# Box-Cox fails because of the negative values.

# Other strategies supported by caret include scaling (z-trans) and PCA
# for simplicity, we'll use scaling


# modeling ----------------------------------------------------------------

# note that we can use our favorite model here, and due to the caret interface,
# we can switch learning algorithms easily. Here, we'll use logistic regression
# I'll leave out the subject-level variables for now

# create a formula from the xyzvars
train.form <- as.formula(paste("class ~",paste(xyzvars,collapse="+")))
# set seed for replicability
set.seed(123)
# figure out what built-in models can be run 
names(getModelInfo())
# train the model
# default is to use a bootstrap to tune parameters
# also available: cv and repeated cv using trControl=trainControl(...)
# you can also choose your own values for a grid search of hyperparameters
# using tuneGrid=expand.grid(...)
# note, the following takes a little time to run, so I pre-ran it

# fit1 <- train(train.form,data=train.set,preProcess="scale",
#               method="glmnet",tuneLength=3)


plot(fit1)
# plot(fit1,type="level") # doesn't seem to work here
print(fit1)

# pro tip: setting the seed before training enables you to replicate results
# you can also compare models if you set the seed, though setting up
# folds by hand for CV might be a better solution (and using index= in trainControl)

# assessment --------------------------------------------------------------

pred <- predict(fit1,val.set)
confusionMatrix(pred,val.set$class)

# clean up ----------------------------------------------------------------

stopCluster(cl)
