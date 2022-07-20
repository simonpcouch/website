---
title: "Running R Scripts on a Schedule with GitHub Actions"
date: '2020-12-27'
slug: r-github-actions-commit
tags:
  - rstats
  - git
subtitle: ''
image:
  caption: ''
  focal_point: ''
  preview_only: yes
summary: "Some pointers on running R scripts and committing their results to a GitHub repository on a regular interval using Actions."
---



I have an R script that queries data from a server that only supplies live data, and I want to run it on a regular basis, saving the results with each run. This problem gets at the intersection of a few things that are often hard (for me) to get right:

- **running computations regularly**: CRON, task schedulers, servers... out of my element. 
- **setting up R**: It's goofy enough to tackle on your own computer! Doing it remotely can get tricky. 
- **saving things**: File paths on drives that aren't, like, mine? Yikes.

I made many mistakes on the way to combining the solutions to these problems effectively, and thought it would be worth a short write-up of the approach I landed on! The solution looks something like this:

* Write your script, save the things
* Situate your script in a package
* Host your package in a GitHub repository
* Set up a GitHub Action

For an example of what the final product could look like, I've made a publicly-available [example repository](https://github.com/simonpcouch/scheduled-commit-action) with everything you'll need to get going! If you're familiar with Git, forking this repository rather than setting yours up from scratch might save you some time. No worries if not.

*Disclaimer*: I don't know what I'm doing! There are likely better ways of the doing the thing I'm about to show you. Please feel free to file PRs or share other approaches. 🙂

## Write your R script, save the things

I imagine most uses for this type of setup will include querying some sort of livestreamed data. I'll be using a relatively simple script in this example. First, I draw ten numbers from the standard normal, assigning them to an object `x`. Then, I save `x` with a filename that gives the time that I generated the numbers.

```
x <- rnorm(1:10)
save(x, file = paste0("data-raw/data_", make.names(Sys.time()), ".Rda"))
```

As I write this, the output of that `file` argument looks like:

```
"data-raw/data_X2020.12.27.08.26.06.Rda"
```

![It ain't much, but it's honest work.](https://i.kym-cdn.com/entries/icons/original/000/028/021/work.jpg)

Your file path should be relative to your current working directory. I decided to make a folder called `data-raw` to save my results into. You'll only need to save your results to file if you'd eventually like to commit them to the GitHub repository you're working inside of.

While you're putting together your script, keep an eye on what R packages you're making use of! Make sure you're calling `library(packagename)` for each package that gets used in your script.

## Situate your script in an R package

If you haven't worked with the internals of an R package before, this step might feel intimidating, but the R community has put together a few tools to make your experience as pleasant as possible!

Situating your script in an R package means that you'll have access to a lot of helpful tools to tell GitHub Actions, the server you'll eventually run the script on, how to set up an R session like yours.

To get started, we'll make use of the [`usethis`](https://usethis.r-lib.org/) package to set up a minimal package. If you haven't installed `usethis` before, you can use the following code:

```
install.packages("usethis")
```

Creating a package template:

```
usethis::create_package(path = "packagename")
```

`usethis` should automatically open the R project for the package you just made!

This function, among other things, will make you a `DESCRIPTION` file to fill out. [Description files](https://r-pkgs.org/description.html) allow you to supply some basic information about a package, such as its name and description, the name of its authors, and the packages it relies on.

For the most part, if you want, you can leave this file as is. (I think it's kind of fun to fill this stuff out, but you do your thing.🐣) If you use any non-base packages in your script, though, you _will_ need to add an `Imports:` field. This field allows you to specify all of the packages your script uses so that GitHub Actions can install what it needs to before it runs your script. You'll want to include any package you called `library()` on in your original script here. I don't use the `Imports:` field at all in my example repository since I don't use any non-base packages, but you can check out the [`stacks` description file](https://github.com/tidymodels/stacks/blob/main/DESCRIPTION) to see how `Imports:` is formatted!

After editing the `DESCRIPTION`, drop your `.R` script in a folder called `R`—this is where most R scripts go in R packages. If you want to read more about best practices for writing R packages, check out the [R Packages](https://r-pkgs.org/) book by Hadley Wickham and Jenny Bryan.

## Host your package in a GitHub repository

If you're not familiar with Git and GitHub, this component of the workflow might be the trickiest for you. Karl Broman wrote a [great primer](https://kbroman.org/pkg_primer/pages/github.html) on getting your package up on GitHub. For more details, you could check out the Git chapter of the [R Packages book](https://r-pkgs.org/git.html) or, for the ultimate Git + R resource, [Happy Git with R](https://happygitwithr.com/) by Jenny Bryan.

Hosting our package on GitHub gives us access to _Actions_, which, for me, was the selling point of this approach. If you don't have a GitHub Pro account, your repository will need to be publicly-available to have access to unlimited Actions runtime.

## Set up a GitHub Action

GitHub Actions is a tool that allows you to automate all sorts of software development tasks. In the R community, it's widely used to check R packages hosted on GitHub every time they're updated. I use GitHub Actions to help build this website! Here, we'll use another feature of GitHub Actions: CRON scheduling. CRON is a _job scheduler_, allowing you to run scripts at a regular interval (or any specific time or set of times in the future, generally). 

The building blocks of Actions are _workflows_. Workflows are YAML files that allow you to specify _when_ and _how_ to carry out some software development task. Here, our _when_ is a regular interval of time—hourly, daily, etc. The _how_, in addition to your R script itself, involves telling Actions how to set up an R session that looks like yours. Thankfully, the R community has put together tools to set up an R session that looks like that which an R package requires. Since we've situated our script in an R package, we can make use of those tools.

The process for building our workflow will look something like this:

1) Specify your time interval
2) Set up R
3) Run your script
4) Save the results of your script

You'll first need to make your workflow file. It should live inside of a `.github/workflows` folder and have a `.yaml` extension. Mine looks like this:

```
├── .github
│   ├── workflows
│       ├── schedule-commit.yaml
```

That `schedule-commit` file name can be whatever you want!

### 1) Specify your time interval

We will use CRON to specify how often we want to run our script.

The most important part of CRON for you to understand is how to specify the interval of time you're working with using an _expression_; do you want to run this script every 5 minutes? hourly? daily? monthly? These expressions are highly formatted strings that allow you to specify all sorts of different conditions that help you specify when to run a script. Rather than learning the rules for formatting these expressions, I recommend making use of one of many online tools to assist you in specifying your time interval. My favorite tool for generating CRON expressions is [https://crontab.cronhub.io/](https://crontab.cronhub.io/). 

I want to run my script every hour. The CRON expression for this interval is `0 * * * *`. Situated inside of the workflow formatting, it looks like:

```
on:
  schedule:
    - cron: "0 * * * *"
```

### 2) Set up R

Next, we'll set up an R session on the Actions server. This approach borrows heavily from a few different [template actions](https://github.com/r-lib/actions) supplied by the `r-lib` team!

Briefly, this component of the script 

* specifies the kind of build system to use (I use an ubuntu server here)
* sets R environmental variables and configures access to the GitHub repo
* installs R
* installs needed R packages (specified in the `DESCRIPTION`)
* caches stuff that will be helpful to keep around for the next time this Action is run

```
jobs:
  generate-data:
    runs-on: ${{ matrix.config.os }}

    name: ${{ matrix.config.os }} (${{ matrix.config.r }})

    strategy:
      fail-fast: false
      matrix:
        config:
          - {os: ubuntu-latest,   r: 'release'}

    env:
      R_REMOTES_NO_ERRORS_FROM_WARNINGS: true
      RSPM: ${{ matrix.config.rspm }}
      GITHUB_PAT: ${{ secrets.GITHUB_TOKEN }}

    steps:
      - uses: actions/checkout@v2

      - uses: r-lib/actions/setup-r@master
        with:
          r-version: ${{ matrix.config.r }}
          http-user-agent: ${{ matrix.config.http-user-agent }}

      - uses: r-lib/actions/setup-pandoc@master

      - name: Query dependencies
        run: |
          install.packages('remotes')
          install.packages('sessioninfo')
          saveRDS(remotes::dev_package_deps(dependencies = TRUE), ".github/depends.Rds", version = 2)
          writeLines(sprintf("R-%i.%i", getRversion()$major, getRversion()$minor), ".github/R-version")
        shell: Rscript {0}

      - name: Cache R packages
        uses: actions/cache@v1
        with:
          path: ${{ env.R_LIBS_USER }}
          key: ${{ runner.os }}-${{ hashFiles('.github/R-version') }}-1-${{ hashFiles('.github/depends.Rds') }}
          restore-keys: ${{ runner.os }}-${{ hashFiles('.github/R-version') }}-1-

      - name: Install dependencies
        run: |
          remotes::install_deps(dependencies = TRUE)
        shell: Rscript {0}
```

### 3) Run your script

With R now set up, you'll want to run the script you wrote up. Note the indentation here—this part of the script extends the "job" you have going already.

```
      - name: Generate data
        run: |
          source("R/job.R")
        shell: Rscript {0} 
```

I called my own script `job.R`. You'll want to switch that name out for whatever you called your own!

### 4) Save the results of your script

This next step takes the results of your script that you've "saved" and stores them permanently in your repository. It configures a bot user and then commits and pushes for you. The second to last line gives the commit message that the bot will use for each commit.

```
      - name: Commit files
        run: |
          git config --local user.email "actions@github.com"
          git config --local user.name "GitHub Actions"
          git add --all
          git commit -am "add data"
          git push 
```

Again, notice the indentation! This part of the script extends the current job further.

There are many useful workflows for which this step isn't needed. For example, the tidymodels team uses a repository called [extratests](https://github.com/tidymodels/extratests) to run additional unit tests on some of their packages every night. The Action runs checks on their packages on a schedule and just leaves the results in the metadata for the Action rather than pushing to the repository.

### That's a wrap!

That's it!

After you push this workflow and all of the other files in your package, you're good to go. _I'd recommend waiting an hour or so before checking in on your repository to see if it's working_; sometimes it takes Actions a bit to get up and running.

In your GitHub repository, the "Actions" tab will show you information about how your workflow went. To help debug, I like to include a short script at the end of my workflows to tell me the packages I had installed and their versions.

```
      - name: Session info
        run: |
          options(width = 100)
          pkgs <- installed.packages()[, "Package"]
          sessioninfo::session_info(pkgs, include_base = TRUE)
        shell: Rscript {0}
```

Generally, debugging Actions can be pretty tricky compared to code you've run locally. I'd recommend running your script in full with a fresh R environment before pushing your work out to GitHub, and once there, lean on Google heavily.😉 In addition to the error message you're seeing, it's often helpful to include `r-lib/actions` or `github actions r` in your search query.

To see the full version of the workflow I've outlined here, check it out [here](https://github.com/simonpcouch/scheduled-commit-action/blob/master/.github/workflows/schedule-commit.yaml). A full example repository with all of the code and metadata needed is [publicly available](https://github.com/simonpcouch/scheduled-commit-action).

I appreciate you reading, and I hope this was helpful!
