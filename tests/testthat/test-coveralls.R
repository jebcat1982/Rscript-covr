context("coveralls")

ci_vars <- c(
  "APPVEYOR" = NA,
  "APPVEYOR_BUILD_NUMBER" = NA,
  "APPVEYOR_REPO_BRANCH" = NA,
  "APPVEYOR_REPO_COMMIT" = NA,
  "APPVEYOR_REPO_NAME" = NA,
  "BRANCH_NAME" = NA,
  "BUILD_NUMBER" = NA,
  "BUILD_URL" = NA,
  "CI" = NA,
  "CIRCLECI" = NA,
  "CIRCLE_BRANCH" = NA,
  "CIRCLE_BUILD_NUM" = NA,
  "CIRCLE_PROJECT_REPONAME" = NA,
  "CIRCLE_PROJECT_USERNAME" = NA,
  "CIRCLE_SHA1" = NA,
  "CI_BRANCH" = NA,
  "CI_BUILD_NUMBER" = NA,
  "CI_BUILD_URL" = NA,
  "CI_COMMIT_ID" = NA,
  "CI_NAME" = NA,
  "CODECOV_TOKEN" = NA,
  "DRONE" = NA,
  "DRONE_BRANCH" = NA,
  "DRONE_BUILD_NUMBER" = NA,
  "DRONE_BUILD_URL" = NA,
  "DRONE_COMMIT" = NA,
  "GIT_BRANCH" = NA,
  "GIT_COMMIT" = NA,
  "JENKINS_URL" = NA,
  "REVISION" = NA,
  "SEMAPHORE" = NA,
  "SEMAPHORE_BUILD_NUMBER" = NA,
  "SEMAPHORE_REPO_SLUG" = NA,
  "TRAVIS" = NA,
  "TRAVIS_BRANCH" = NA,
  "TRAVIS_COMMIT" = NA,
  "TRAVIS_JOB_ID" = NA,
  "TRAVIS_JOB_NUMBER" = NA,
  "TRAVIS_PULL_REQUEST" = NA,
  "TRAVIS_REPO_SLUG" = NA,
  "WERCKER_GIT_BRANCH" = NA,
  "WERCKER_GIT_COMMIT" = NA,
  "WERCKER_GIT_OWNER" = NA,
  "WERCKER_GIT_REPOSITORY" = NA,
  "WERCKER_MAIN_PIPELINE_STARTED" = NA)

read_file <- function(file) paste(collapse = "\n", readLines(file))#readChar(file, file.info(file)$size)
test_that("coveralls generates a properly formatted json file", {

  with_envvar(c(ci_vars, "CI_NAME" = "FAKECI"),
    with_mock(
      `httr:::POST` = function(...) list(...),
      `httr::content` = identity,
      `httr::upload_file` = function(file) readChar(file, file.info(file)$size),

      res <- coveralls("TestS4"),
      json <- jsonlite::fromJSON(res$body$json_file),

      expect_equal(nrow(json$source_files), 1),
      expect_equal(json$service_name, "fakeci"),
      expect_match(json$source_files$name, rex::rex("R", one_of("/", "\\"), "TestS4.R")),
      expect_equal(json$source_files$source, read_file("TestS4/R/TestS4.R")),
      expect_equal(json$source_files$coverage[[1]],
        c(NA, NA, NA, NA, 5, 2, 5, 3, 5, NA, NA, NA, NA, NA, NA, NA, NA, NA,
          NA, NA, NA, NA, 1, NA, NA, NA, NA, NA, 1, NA, NA, NA, NA, NA, 1, NA))
    )
  )
})

test_that("coveralls can spawn a job using repo_token", {

  with_envvar(c(ci_vars, "CI_NAME" = "DRONE"),
    with_mock(
      `httr:::POST` = function(...) list(...),
      `httr::content` = identity,
      `httr::upload_file` = function(file) readChar(file, file.info(file)$size),
      `covr::system_output` = function(...) paste0(c("a","b","c","d","e","f"), collapse="\n"),

      res <- coveralls("TestS4", repo_token="mytoken"),
      json <- jsonlite::fromJSON(res$body$json_file),

      expect_equal(is.null(json$git), FALSE),
      expect_equal(nrow(json$source_files), 1),
      expect_equal(json$service_name, NULL),
      expect_equal(json$repo_token, "mytoken"),
      expect_match(json$source_files$name, rex::rex("R", one_of("/", "\\"), "TestS4.R")),
      expect_equal(json$source_files$source, read_file("TestS4/R/TestS4.R")),
      expect_equal(json$source_files$coverage[[1]],
        c(NA, NA, NA, NA, 5, 2, 5, 3, 5, NA, NA, NA, NA, NA, NA, NA, NA, NA,
          NA, NA, NA, NA, 1, NA, NA, NA, NA, NA, 1, NA, NA, NA, NA, NA, 1, NA))
    )
  )
})

test_that("generates correct payload for Drone and Jenkins", {

  with_envvar(c(ci_vars, "CI_NAME" = "FAKECI", "CI_BRANCH" = "fakebranch", "CI_REMOTE" = "covr"),
    with_mock(
      `covr::system_output` = function(...) paste0(c("a","b","c","d","e","f"), collapse="\n"),
      git <- jenkins_git_info(),

      expect_equal(git$head$id, jsonlite::unbox("a")),
      expect_equal(git$head$author_name, jsonlite::unbox("b")),
      expect_equal(git$head$author_email, jsonlite::unbox("c")),
      expect_equal(git$head$commiter_name, jsonlite::unbox("d")),
      expect_equal(git$head$commiter_email, jsonlite::unbox("e")),
      expect_equal(git$head$message, jsonlite::unbox("f")),
      expect_equal(git$branch, jsonlite::unbox("fakebranch")),
      expect_equal(git$remotes[[1]]$name, jsonlite::unbox("origin")),
      expect_equal(git$remotes[[1]]$url, jsonlite::unbox("covr"))

    )
  )
})
