---
title: "Big Things (Developer Documentation pt. 4)"
date: '2021-05-13'
slug: dev-docs-p4
tags:
  - rstats
  - stacks
  - tidymodels
  - dev-docs
subtitle: ''
image:
  caption: ''
  focal_point: ''
  preview_only: yes
summary: "On the tension between documenting R packages exhaustively and maintainably."
---

> This is the last of four blog posts on the development process of the {stacks} package, excerpted from my Reed senior thesis project _Tidy Model Stacking with R_.
>
> **Part 1:** [_Introduction_](https://blog.simonpcouch.com/blog/dev-docs-p1/)
> 
> **Part 2:** [_Splitting Things Up_](https://blog.simonpcouch.com/blog/dev-docs-p2/)
>
> **Part 3:** [_Naming Things_](https://blog.simonpcouch.com/blog/dev-docs-p3/)



The final blog post in this series is somewhat less argumentative than the first two, but speaks to Reiderer's concept of "developer documentation" much the same. Rather than (explicitly) defending my API choices, I'd like to provide some context for some of the more wiggly elements of {stacks}' infrastructure. That is, some components of the package's implementation are weird---some may say hacky, if feeling particularly violent---and the reasoning for these choices often tracks back to the same issue; things are Big. 

Big things. I mean this both in the sense that many of the inputs to {stacks} functions are almost inevitably very large data objects requiring a non-negligible amount of computing time to generate and that {stacks} itself takes a long time to do its thing, returning data objects that are even larger than it was supplied. The tools of the R package development trade are varyingly equipped to accommodate such things---those of the Big variety---and thus, some wiggliness is required. I'll continue using Big to evoke some intersection of these two qualities, both for notational convenience and goofiness.

There are a few things I'm referring to when I say "tools of the R package development trade." Initially, I mean R itself and the tools provided by the R core team to articulate what a proper package looks like and check that this is the case. Namely, the `R CMD check` set of checks exhaustively defines the bounds of a "valid" R package. Further, I also mean the Comprehensive R Archive Network (CRAN), a centralized repository that curates and hosts thousands of the most widely used packages in the R community, as well as the team of volunteers supporting it. The CRAN team also contributes and maintains its own extensions to `R CMD check` for packages hosted in its repositories, asserting guidelines that improve maintainability (and thus user experience) for both the CRAN team and contributed package maintainers [(Claes, 2014)](https://www.researchgate.net/publication/271482576_On_the_maintainability_of_CRAN_packages).

Each of the tools mentioned above are tremendously positive forces in the R community. At the same time, they must make assertions (whether explicit or implicit) about the "smells and feels" of R packages that are one-size-fits-all, so to speak, in order to shepherd the homogeneity required to articulate coherent bounds on what an R package _is_ [(Bryan, 2018)](https://www.rstudio.com/collections/additional-talks/code-smells-and-feels-user2018-brisbane/#:~:text=Jenny%20Bryan%20%7C&text=%22Code%20smell%22%20is%20an%20evocative,be%20fiddly%20and%20bug%2Dprone.). In the case of {stacks}, some of these assertions introduce the need for particularly wiggly workarounds.

The following bounds, excerpted from the CRAN repository policy, introduce the need for the vast majority of these wiggles:

* "Checking the package should take as little CPU time as possible"--in practice, this is a 10 minute threshold.  Notably, the CRAN team places a bound on runtime of package examples: "Examples should run for no more than a few seconds each: they are intended to exemplify to the would-be user how to use the functions in the package."
* "Packages should be of the minimum necessary size... neither data nor documentation should exceed 5MB."

Again, I contend that the above restrictions are justified and necessary given the scope of the CRAN team's resources. Beyond making the maintenance of CRAN a more feasible task, too, these restrictions also provide expectations from which popular package development tools can draw from in determining functionality. 

I'll begin this by demonstrating more precisely what I mean by Big. Then, in the following section, I will illustrate more clearly the tension between this Bigness and the aforementioned bounds. In the following sections, I describe three strategies for reckoning with this tension---wiggling thoughtfully, if you will.

### Big: a demonstration

Before I approach solutions, I want to make sure that I characterize the problem here concretely. I claim that, for one, the inputs to {stacks} functions are the culmination of computationally intensive processes and are themselves large data objects. Further, I claim that the operations carried out by {stacks} are computationally intensive and output large data objects. My definitions of "long running" and "large" here are relative to the 10 minute check time and 5MB bundled package size limits, respectively. In this subsection, I first demonstrate these two claims, and only consider their implications in the following subsections.

_The inputs_: The primary argument inputs to {stacks} functions are model definitions outputted from functions in the [{tune}](http://tune.tidymodels.org/) package. Model definitions specify one or more candidate members, and supply the results of fitting each candidate member to resamples of the training data.

To illustrate, lets return to the model objects mentioned in the second blog post. In that post, we made use of model objects specifying 11 candidate members trained on 2197 observations---a set of building blocks for an ensemble that is quite modest in comparison with many applications of stacked ensemble modeling. There are nearly 200 lines of code needed to generate those objects, elapsing around 45 seconds in runtime on a machine that generally outperforms CRAN check farms by a small but non-negligible amount.^[The code mentioned here will be available when the full thesis is made available--I'll make sure to note here when that's the case!] The code contained in this section does not include any of the `add_candidates`, `blend_predictions`, or `fit_members` steps, though its runtime already takes up a substantial portion of the time allotted for a CRAN package's examples to run. 

An alternate approach (discussed later) would be to supply example results of these computations for use in examples and unit tests rather than generating them on `R CMD check`. However, the `svm-res`, `lin_reg_res`, and `knn_res` data objects to be inputted to `add_candidates` take up 13.2MB of memory, more than twice the amount of storage typically allotted to the entirety of a CRAN-published R package. This does not include any of the intermediate objects generated in the process of specifying these objects.

Surely, then, {stacks}' inputs are Big.

_{stacks}' objects and computations_: In much the same way as the packages generating its inputs, the operations that {stacks} carries out are computationally intensive and generate large data objects.

In contrast to the earlier section, with the necessary input objects generated, the code in the following sections demonstrating {stacks}' functionality can be summarized in only a few lines of code.


```r
st <- 
  stacks() %>%
  add_candidates(knn_res) %>%
  add_candidates(lin_reg_res) %>%
  add_candidates(svm_res) %>%
  blend_predictions() %>%
  fit_members()
```

On the same machine mentioned earlier, the code to execute the {stacks} pipeline in full takes about half of the time required to generate its inputs. Thus, one start to finish example, assuming {stacks} doesn't supply intermediate objects to reduce runtime, requires around a minute of compute time. Note that this runtime, taking up a tenth of the total allotted package check time on a machine that outperforms CRAN's check farms, provides one minimal example demonstrating functionality in one help-file.

Further, the `st` object specified above takes up 15.2MB in memory, over three times the amount of storage typically allotted to the entirety of a CRAN-published R package.

Big things abound! Wiggliness follows.

### The reason for the squeezin', signal for the wiggle

In effect, a CRAN-published R package must take 10 or less minutes to pass `R CMD check`. `R CMD check` is a suite of tests ensuring that the form and function of an R package aligns with conventions. Most all of the steps require negligible computing time to run---for example, `R CMD check` ensures that all files included in the package build match some pre-specified dictionary of file names and checks that a file exists inside of the `R/` subdirectory. However, other checks are substantially more computationally intensive. Of note, `R CMD check`, by default, will run all examples in the package's help-files as well as the package's unit tests. This practice is surely justifiable, as failing examples or unit tests almost certainly indicate that a package is not functioning as intended. However, in light of the constraint that examples and unit tests must run in a set amount of time, this practice introduces a trade-off for packages with Big things. Package developers must strike a balance between, on one hand, documenting and unit testing their packages thoroughly enough to encourage a positive user experience, and on the other, documenting and unit testing sparingly enough to meet the check time limitations.

In a similar vein, to be hosted on CRAN repositories, there is an effective 5MB bound on the size of a bundled R package. More specifically, "neither data nor documentation should exceed 5MB." R packages, other than data and documentation, are largely (if not exclusively) plain text. Note, though, this bound is only relevant for the bundled package---files of any size can be stored in the source code as long as they are not included in the bundled version of the package sent to CRAN. Again, though, package developers must strike a balance between providing sufficient data and documentation to encourage a positive user experience and, on the other, minimizing bundled package size in order to come in under the 5MB limit.

There are several strategies beyond abbreviating example usages and unit testing coverage to decrease package check time and bundled size. For one, packages with Big inputs can provide example input objects that are the culmination of long-running computations to use throughout package examples. Further, documentation can lean more heavily on other help-file sections to document concepts in repeated long-form explanations and syntax in argument descriptions. Finally, there are several techniques, some more wiggly than others, to conditionally run examples and unit tests. I'll consider each of these strategies in the following three subsections, noting their implications for shortening package check times and reducing bundled package size.

### Example input objects

An approach taken by several R packages in the {tidymodels} ecosystem to reduce package check time is to supply R data objects with an R package for use in examples and unit tests. As noted above, the inputs to {stacks}' `add_candidates` are the culmination of a significant amount of runtime. Rather than regenerating these objects each time some functionality is to be demonstrated, the package can supply a set of R data objects with the package that can simply be loaded and passed to {stacks} functions as needed. In this way, the runtime of an example or unit test is limited only to the time required by {stacks} to carry out its functionality, eliminating the need to take up package check time carrying out operations implemented in other packages.

To this end, the {stacks} package provides a collection of R data objects for use in examples and unit tests. The objects are based on `tree_frogs`, a subset of an experimental data set from a study of tree frog embryo hatching [(Jung, 2020)](https://jeb.biologists.org/content/223/24/jeb236141).


```r
tree_frogs
```

```
## # A tibble: 1,212 x 7
##    clutch treatment  reflex    age t_o_d     hatched latency
##    <fct>  <chr>      <fct>   <dbl> <chr>     <chr>     <dbl>
##  1 168    control    full   466965 morning   yes          22
##  2 145    gentamicin full   404310 afternoon no           NA
##  3 149    gentamicin full   426220 night     no           NA
##  4 100    control    mid    355360 night     no           NA
##  5 230    gentamicin mid    356535 night     no           NA
##  6 99     control    low    361180 night     yes         360
##  7 145    gentamicin full   400070 afternoon no           NA
##  8 133    control    full   401595 afternoon yes         106
##  9 100    control    mid    357810 night     yes         180
## 10 182    control    mid    358410 night     no           NA
## # … with 1,202 more rows
```

In addition to the data set itself, the package provides a number of other example data objects. Excerpting from the documentation entry included in each of the package's help-files:

> {stacks} provides some resampling objects and datasets for use in examples and vignettes derived from a study on 1212 red-eyed tree frog embryos!
> 
> Red-eyed tree frog (RETF) embryos can hatch earlier than their normal 7ish days if they detect potential predator threat. Researchers wanted to determine how, and when, these tree frog embryos were able to detect stimulus from their environment. To do so, they subjected the embryos at varying developmental stages to "predator stimulus" by jiggling the embryos with a blunt probe. Beforehand, though some of the embryos were treated with gentamicin, a compound that knocks out their lateral line (a sensory organ). Researcher Julie Jung and her crew found that these factors inform whether an embryo hatches prematurely or not!
> 
> Note that the data included with the stacks package is not necessarily a representative or unbiased subset of the complete dataset, and is only for demonstrative purposes.
> 
> `reg_folds` and `class_folds` are `rset` cross-fold validation objects from `rsample`, splitting the training data into for the regression and classification model objects, respectively. `tree_frogs_reg_test` and `tree_frogs_class_test` are the analogous testing sets.
> 
> `reg_res_lr`, `reg_res_svm`, and `reg_res_sp` contain regression tuning results for a linear regression, support vector machine, and spline model, respectively, fitting `latency` (i.e. how long the embryos took to hatch in response to the jiggle) in the `tree_frogs` data, using most all of the other variables as predictors. Note that the data underlying these models is filtered to include data only from embryos that hatched in response to the stimulus.
> 
> `class_res_rf` and `class_res_nn` contain multiclass classification tuning results for a random forest and neural network classification model, respectively, fitting `reflex` (a measure of ear function) in the data using most all of the other variables as predictors.
> 
> `log_res_rf` and `log_res_nn`, contain binary classification tuning results for a random forest and neural network classification model, respectively, fitting `hatched` (whether or not the embryos hatched in response to the stimulus) using most all of the other variables as predictors.

This excerpt is included in help-files throughout the package where the example objects are used, and suffixed with the following:

> See `?example_data` to learn more about these objects, as well as browse the source code that generated them.

The linked `?example_data` help-file (aliased by the names of each of the example objects) also includes the excerpt, and is suffixed with the source code used to generate the objects; an R Markdown document is appended to the documentation entry via the [{roxygen2}](http://roxygen2.r-lib.org/) `@includeRmd` tag, providing the source code to regenerate the exported example objects or generate intermediate un-exported objects in the workflow. Only the raw data source and final `tune_results` data objects---suitable for input to {stacks} functions---are included in the bundled package, to minimize bundled package size.

Then, in each example section throughout the package where the example objects are used, the following excerpt prefixes the section:


```r
# see the "Example Data" section above for
# clarification on the objects used in these examples!
```

This approach ensures that the source of the example objects is clear to the user. Further, including a fully worked example of appropriate usage of requisite model specification with other functionality from {tidymodels} clarifies specificities of using the ecosystem to generate {stacks}' inputs.

There are a few notable drawbacks to the approach of supplying example data objects with the package that are the result of {stacks}' dependencies. 

Principally, these data objects are not automatically generated, and will not automatically update when a {stacks} dependency is updated. Thus, if a {tidymodels} package makes a breaking change for {stacks}, but {stacks} only checks its examples and unit tests relative to the stored data object, then the breaking change will be undetected until the example object is updated manually. This drawback is somewhat remedied by [_extratests_](https://github.com/tidymodels/extratests), a repository running a more exhaustive set of checks on a regular schedule, developed and maintained by the {tidymodels} team in reaction to exactly this issue. Further, {tidymodels} developers work in close collaboration to ensure that functionality is tightly integrated across packages and thus likely anticipate which changes will break functionality in {stacks}. However, for breaking changes arising from outside of the {tidymodels} ecosystem, the package is unprotected.

The other notable drawback here is that this approach is simply not well-adopted, and thus somewhat awkward for users and casual contributors. For users of the {tidymodels} ecosystem, and other ecosystems that are prone to run up against the same issue and thus adopt a similar strategy, this approach will be familiar. However, for users whose first exposure to the {tidymodels} is {stacks}, this approach is surely strange. Further, for potential contributors to the package, the need for understanding which changes would alter the structure of example data objects in order to submit an appropriate contribution is prohibitive. 

Altogether, supplying example input objects reduces the computational intensity of running examples and unit testing {stacks}. It also leads to more targeted documentation in that, for advanced {tidymodels} users, documentation for {stacks} functions need only document {stacks} functionality. For others, supplying example objects provides an applied example for more verbose help-files outlining the necessary steps to generate {stacks} inputs. Unfortunately, the approach also results in {stacks} being particularly vulnerable to unanticipated breaking changes in its dependencies, and is also awkward for some users.

### Restructuring help-files 

Another approach that {stacks} takes in attempting to both document functionality thoroughly and minimize package check time is to redistribute example code that is redundant with package unit tests to other help-file sections that are not executed at check time.

A notable example is that outlined above; all code used to generate example objects exported with the package is included in the "Example Objects" sections of the core functions, and is only executed when manually called following relevant updates to {stacks} dependencies. All of the functionality in this section is unit tested and documented in the relevant {tidymodels} packages and thus need not be redundantly checked in {stacks} (even though {stacks} explicitly relies on its functionality.)

Further, R packages often document the syntax to use function arguments within the example section. Since sensitivity to function arguments is tested extensively in the package unit tests, and each additional example provided in the help-files increases check time, {stacks} instead redistributes much of its argument-level documentation to the actual argument documentation and custom sections. In addition to plain text, the argument-level documentation provides several examples of code that could possibly be supplied to the argument. This approach also encourages a more granular level of documentation, focusing in on approaches to manipulating one specific argument. However, this approach may also obscure the relationships between arguments, and may feel awkward for users who are used to navigating help-files in a more example-centric manner.

Finally, the package uses the `@inherits` tag from {roxygen2} in order to consolidate example code sections with shared functionality. As such, example code provided with the package help-files can appear in a number of help-files but only be executed once.

### Running conditionally 

The approach of using `if` statements to conditionally run examples and unit tests likely ought to have been forefronted, as its most straightforward implementations are the least wiggly of all of those mentioned throughout this section to reduce package check time. On the other hand, {stacks} makes use of some particularly wiggly approaches to run examples and unit tests conditionally.

As for the more standard approaches, one can use a number of conditional clauses to skip examples and unit tests in some cases. 

As for examples, the `\donttest{}` example tag indicates that an example ought to run successfully, but should not be executed at check time. Nonetheless, check options exist to run such examples irrespective of the presence of this tag, and CRAN runs some checks with these options enabled. Examples tagged with `\donttest{}` present like any other example in built documentation. On the other hand, the `\dontrun{}` example tag indicates that an example should never be executed at check time, and is flagged with a `## Don't run:` tag in built documentation. Some packages will use this tag on code that should execute successfully and note to ignore the `## Don't run:` tag preceding the example in question.

As for unit tests, [{testthat}](https://testthat.r-lib.org/) offers an extensive suite of `skip_if_*`-style functions, allowing users to skip unit tests based on a number of relevant conditions, like `skip_if_offline`, `skip_on_ci` (as in, skip on continuous integration platforms), or `skip_on_cran`. When preceding a block of unit tests, these functions will halt execution of the unit tests in question and move on to others.

{stacks} uses an approach that is inspired by these conditional skipping functions. In the spirit of the approach noted in the example objects section, the source of {stacks} supplies a `helper_data` data object including a number of compiled objects for use in unit testing. The `helper_data` serves two purposes. For one, it reduces package check time by storing the output of functions required to generate input to {stacks} functions. Additionally, the data object supplies reference objects to which objects generated on-the-fly during unit testing can be compared. If these reference objects, generated with the exact same code as the objects generated on-the-fly, differ from the objects generated during unit testing, then a unit test fails. If the structure of a {stacks} output is truly intended to change, the `helper_data` object is simply regenerated with the associated script in `man-roxygen/example_models.Rda`. Note that a small subset of the `helper_data` objects are actually exported as example data objects with the package, as discussed in the example objects section.

However, the `helper_data` data object is large. At the time of writing, this object is 22 Mb, over four times the total allowed package size. Thus, the data object is not actually included in the bundled package, and unit tests running from the bundled version of the package do not have access to the `helper_data`. Wiggliness ensues.

A suite of helper functions are defined preceding the execution of package unit tests. Rather than taking arguments, these functions are sensitive to the environment they're executed in.


```r
get_current_branch <- function() {
  gh_ref <- Sys.getenv("GITHUB_REF")
  
  if (!identical(gh_ref, "")) {
    gsub("refs/heads/", "", gh_ref)
  } else {
    NA
  }
}

on_github <- function() {
  !is.na(get_current_branch())
}

on_cran <- function() {
  !identical(Sys.getenv("NOT_CRAN"), "true")
}
```

These helpers help to construct an idiom that determines the following rules for running package unit tests:

* When running locally via `R CMD check` or interactively, utilize the local `helper_data` object in running the entire suite of unit tests.
* When running on a continuous integration platform (in this case, GitHub Actions), locate the `helper_data` object in the appropriate workspace environment and utilize it in running the entire suite of tests.
* When running on CRAN, only run unit tests that don't require the `helper_data` object. This is a very small number of unit tests relative to the full suite included in the non-bundled version of the package, but serves to raise errors and warnings in light of breaking changes in {stacks}' dependencies.

The following code implements this idiom:


```r
if ((!on_cran()) || interactive()) {
  if (on_github()) {
    load(
      paste0(
        Sys.getenv("GITHUB_WORKSPACE"), 
        "/tests/testthat/helper_data.Rda"
        )
      )
  } else {
    load("/tests/testthat/helper_data.Rda")
  }
}
```

Tests requiring the `helper_data` are prefixed with a `skip_on_cran` call.

This approach to conditionally running examples and unit tests allows {stacks} to fulfill CRAN's check time requirements in the published version of the package while also exhaustively unit testing the developmental version of {stacks} via continuous integration on the package repository as well as the {tidymodels} team's _extratests_ repository.

### Wiggling thoughtfully

Altogether, I've demonstrated some techniques that {stacks} makes use of to accommodate the package check time and bundled size limits. Again, these limitations from CRAN are necessary and helpful to ensure the maintainability of its ecosystem, and thus improve user experience in the end. At the same time, though, packages that pass around and manipulate large data objects must make compromises in their form and function to accommodate these limits. In this section, I've suggested some approaches to minimize negative impact on user experience while reckoning with these limits, perhaps even using this challenge as a prompt to examine one's documentation and unit testing strategies critically.
