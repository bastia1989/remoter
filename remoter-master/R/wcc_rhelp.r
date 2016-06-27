#' rhelp
#' 
#' Remote R Help System
#'
#' @description
#' Provide the primary interface to the help systems as \code{utils::help()}
#' 
#' @param topic
#' A topic as in \code{utils::help()}
#' @param package
#' A package as in \code{utils::help()}
#' @param lib.loc
#' A lib location as in \code{utils::help()}
#' @param verbose
#' if verbose on/off as in \code{utils::help()}
#' @param try.all.packages
#' if try all packages as in \code{utils::help()}
#' @param help_type
#' only text is supported in \pkg{remoter}
#'
#' @examples
#' \dontrun{
#' ### Prompts are listed to clarify when something is eval'd locally vs
#' ### remotely
#' > # suppressMessages(library(remoter, quietly = TRUE))
#' > # client()
#' > remoter::client("192.168.56.101")
#'
#' remoter> rhelp("plot")
#' remoter> rhelp(package = "remoter")
#' remoter> rhelp("plot", package = "remoter")
#'
#' remoter> rhelp("dev.off")
#' remoter> rhelp("dev.off", package = "remoter")
#' remoter> rhelp("dev.off", package = "grDevices")
#'
#' remoter> help("par")
#'
#' remoter> ?`+`
#' remoter> ?`?`
#' remoter> ?"??"
#' remoter> package?base
#' remoter> `?`(package, remoter)
#'
#'
#' remoter> q()
#' >
#' }
#' 
#' @rdname rhelp 
#' @name rhelp
NULL

#' @export
rhelp <- function(topic, package = NULL, lib.loc = NULL,
                  verbose = getOption("verbose"),
                  try.all.packages = getOption("help.try.all.packages"),
                  help_type = getOption("help_type"))
{
	### The next are very stupid but works.
	if (missing(topic))
  txt.head <- "utils::help("
	else
  txt.head <- paste0("utils::help('", as.character(substitute(topic)), "', ")
	
	if (is.null(package))
  package <- "NULL"
	else
  package <- paste0("'", as.character(substitute(package)), "'")
	
	if (is.null(lib.loc))
  lib.loc <- "NULL"
	else
  lib.loc <- paste0("'", as.character(lib.loc), "'")
	
	
	### should give some indicator of the platform of the client.
	
	
  
	help_type <- paste0("'", help_type, "'")
	
	txt <- paste0(txt.head, "package = ", package, ", ",
	"lib.loc = ", lib.loc, ", ",
	"verbose = ", verbose, ", ",
	"try.all.packages = ", try.all.packages, ", ",
	"help_type = ", help_type, ")")
	ret <- eval(parse(text = txt))
	### Deal with "help_files_with_topic" or "packageInfo"
	if (class(ret) == "help_files_with_topic")
  Rd <- print.rhelp_files_with_topic(ret)
	else if (class(ret) == "packageInfo")
  Rd <- print.rpackageInfo(ret)
	else
  Rd <- ret
	
	### Ask client to show
	if (class(ret) != "try-error")
  set.status(need_auto_rhelp_on, TRUE)
	
	### Visible return is necessary because of retmoter_server_eval().
	return(Rd)
}






#' @rdname rhelp 
#' @export
# help <- if(get.status(remoter_prompt_active)==FALSE)utils::help else rhelp



help <- function(topic, package = NULL, lib.loc = NULL, verbose = getOption("verbose"),
try.all.packages = getOption("help.try.all.packages"), 
help_type = getOption("help_type"))
{
  if (is.null(package))
  package <- "NULL"
  else
  package <- paste0("'", as.character(substitute(package)), "'")
  
  
  if (is.null(lib.loc))
  lib.loc <- "NULL"
  else
  lib.loc <- paste0("'", as.character(lib.loc), "'")
  
  help_type <- paste0("'", help_type, "'")
  if (missing(topic))
  txt.head <- "utils::help("
  else
  txt.head <- paste0("utils::help('", as.character(substitute(topic)), "', ")
  
  
  txt <- paste0(txt.head, "package = ", package, ", ",
  "lib.loc = ", lib.loc, ", ",
  "verbose = ", verbose, ", ",
  "try.all.packages = ", try.all.packages, ", ",
  "help_type = ", help_type, ")")
  
	if(get.status(remoter_prompt_active)==FALSE)
  {
  
  ### The next are very stupid but works.
  
  eval(parse(text = txt))
  }
	else
  {   
  
  ret <- eval(parse(text = txt))
  
  ### Deal with "help_files_with_topic" or "packageInfo"
  if (class(ret) == "help_files_with_topic")
  Rd <- print.rhelp_files_with_topic(ret)
  else if (class(ret) == "packageInfo")
  Rd <- print.rpackageInfo(ret)
  else
  Rd <- ret
  
  
  ### Ask client to show
  if (class(ret) != "try-error")
  set.status(need_auto_rhelp_on, TRUE)
  
  
  ### Visible return is necessary because of retmoter_server_eval().
  return(Rd)
  
  }
  }
  
  
  
  #' @rdname rhelp
  #' @export
  `?` <- function(e1, e2)
  {
	if(get.status(remoter_prompt_active)==TRUE)
  {
  
  if (missing(e2))
  txt <- paste0("utils::`?`('", as.character(substitute(e1)), "', )")
  else
  txt <- paste0("utils::`?`('", as.character(substitute(e1)), "', '",
  as.character(substitute(e2)), "')")
  ret <- eval(parse(text = txt))
  
  
  ### Deal with "help_files_with_topic" or "packageInfo"
  if (class(ret) == "help_files_with_topic")
  Rd <- print.rhelp_files_with_topic(ret)
  else
  Rd <- ret
  
  
  ### Ask client to show
  if (class(ret) != "try-error")
  set.status(need_auto_rhelp_on, TRUE)
  
  ### Visible return is necessary because of retmoter_server_eval().
  return(Rd)
  }
  else
  {
  if (missing(e2))
  txt <- paste0("utils::`?`('", as.character(substitute(e1)), "', )")
  else
  txt <- paste0("utils::`?`('", as.character(substitute(e1)), "', '",
  as.character(substitute(e2)), "')")
  eval(parse(text = txt))
  }
  }
  
  #`?` <- if(get.status(remoter_prompt_active)==FALSE) utils::`?` else `?`
  #`?` <- function(e1, e2)
  
  
  
  
  
  
  auto_rhelp_on_local <- function(Rd)
  {
	### Don not use "latin1" to encode the character string.
	encoding <- "UTF-8"
	Encoding(Rd) <- encoding
  
	### Encoding in windows is inconsistent for the Rterm and file.show().
	if (.Platform$OS.type == "windows")
  encoding <- "latin1"
	
  
	### Cast Rd by class.
	if (class(Rd) == "rhelp_files_with_topic")
	{
  temp <- tempfile("Rtxt")
  cat(Rd, file = temp, sep = "\n")
  file.show(temp, title = "R Help", delete.file = TRUE, encoding = encoding)
  }
	else if (class(Rd) == "rpackageInfo")
	{
  temp <- tempfile("RpackageInfo")
  cat(Rd, file = temp, sep = "\n")
  file.show(temp, title = "R Package", delete.file = TRUE,
  encoding = encoding)
  }
	else
  
  cat(Rd, sep = "\n")
	
  
	invisible()
  }
  
  
  
  ### Hijack utils:::print.help_files_with_topic()
  print.rhelp_files_with_topic <- function(x, ...)
  {
	paths <- as.character(x)
	topic <- attr(x, "topic")
	
  
	if (!length(paths))
	{
  ret <- c(gettextf("No documentation for %s in specified packages and libraries.", 
  sQuote(topic)))
  return(invisible(ret))
  }
	
  
	if (attr(x, "tried_all_packages"))
	{
  paths <- unique(dirname(dirname(paths)))
  msg <- gettextf("Help for topic %s is not in any loaded package but can be found in the following packages:",
  sQuote(topic))
  ret <- c(strwrap(msg), "",
  paste(" ", formatDL(c(gettext("Package"), basename(paths)),
  c(gettext("Library"), dirname(paths)), 
  indent = 22)),
  "Specify the package name to rhelp(topic, package = ...)")
  }
	else
	{
  ### Check multiple topics and disable menu selection.
  if (length(paths) > 1L)
  {
  
  msg <- gettextf("Help on topic %s was found in the following packages:",
  sQuote(topic))
  paths <- dirname(dirname(paths))
  txt <- formatDL(c("Package", basename(paths)), c("Library", 
  dirname(paths)), indent = 22L)
  ret <- c(strwrap(msg), "", paste(" ", txt), "",
  "Specify the package name to rhelp(topic, package = ...)")
  }
  else
  {
  
  file <- paths
  pkgname <- basename(dirname(dirname(file)))
  .getHelpFile <- eval(parse(text = "utils:::.getHelpFile"))
  temp <- Rd2txt(.getHelpFile(file), out = tempfile("Rtxt"), 
  package = pkgname, outputEncoding = "UTF-8")
  ret <- readLines(temp, warn = FALSE, encoding = "UTF-8")
  class(ret) <- "rhelp_files_with_topic"
  file.remove(temp)
  }
  }
	
  
	invisible(ret)
  }
  
  
  
  ### Hijack base::print.packageInfo()
  print.rpackageInfo <- function(x, ...)
  {
	temp <- tempfile("RpackageInfo")
	writeLines(format(x), temp)
  ret <- readLines(temp, warn = FALSE, encoding = "UTF-8")
  class(ret) <- "rpackageInfo"
  file.remove(temp)
  
  
  invisible(ret)
  }
  
    