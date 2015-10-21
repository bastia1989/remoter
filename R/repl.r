### For R CMD check
utils::globalVariables(c("continuation", "lasterror", "visible", "should_exit", "remoter_prompt_active", "ret", "lasterror"))


#' State management for the pbdR Client/Server
#' 
#' @export
pbdenv <- new.env()

# options
pbdenv$prompt <- "remoteR"
pbdenv$port <- 55555
pbdenv$remote_addr <- "localhost"
pbdenv$password <- NULL
pbdenv$maxattempts <- 5


# internals
pbdenv$context <- NULL
pbdenv$socket <- NULL
pbdenv$debug <- FALSE
pbdenv$verbose <- TRUE
pbdenv$client_lasterror <- ""

pbdenv$remote_context <- NULL
pbdenv$remote_socket <- NULL

# C/S state
pbdenv$status <- list(
  ret               = invisible(),
  visible           = FALSE,
  lasterror         = NULL,
  shouldwarn        = FALSE,
  num_warnings      = 0,
  warnings          = NULL,
  remoter_prompt_active = FALSE,
  should_exit       = FALSE,
  continuation      = FALSE
)



### just a pinch of sugar
get.status <- function(var)
{
  name <- as.character(substitute(var))
  pbdenv$status[[name]]
}

set.status <- function(var, val)
{
  name <- as.character(substitute(var))
  pbdenv$status[[name]] <- val
  invisible()
}



### ------------------------------------------------
remoter_readline <- function(input)
{
  if (get.status(continuation))
    symb <- "+ "
  else
    symb <- "> "
  
  prompt <- paste0(pbdenv$prompt, symb)
  
  if (pbdenv$whoami == "local")
  {
    ret <- c(input, readline(prompt=prompt))
    ret <- remoter_sanitize(inputs=ret)
  }
  else
    ret <- NULL
  
  return(ret)
}



remoter_client_stop <- function(msg)
{
  pbdenv$client_lasterror <- msg
  cat("Error: ", msg, "\n")
  
  invisible()
}



remoter_sanitize <- function(inputs)
{
  for (i in 1:length(inputs))
  {
    input <- inputs[i]
    if (grepl(x=input, pattern="^(q\\(|quit\\()", perl=TRUE)) 
      inputs[i] <- "remoter_exit()"
    else if (grepl(x=input, pattern="^geterrmessage\\(", perl=TRUE))
      inputs[i] <- pbdenv$client_lasterror
    else if (grepl(x=input, pattern="^(\\?|\\?\\?|help\\()", perl=TRUE))
    {
      remoter_client_stop("Reading help files from the server is currently not supported.")
      inputs[i] <- "invisible()"
    }
    else if (grepl(x=input, pattern="^warnings\\(", perl=TRUE))
    {
      pbdenv$status$shouldwarn <- TRUE
      remoter_show_warnings()
      inputs[i] <- "invisible()"
    }
    else if (grepl(x=input, pattern="^finalize\\(", perl=TRUE))
    {
      inputs[i] <- "remoter_exit()"
    }
    else if (input == "")
      inputs[i] <- "invisible()"
  }
  
  return(inputs)
}



is.error <- function(obj)
{
  if (inherits(obj, "try-error") || inherits(obj, "error"))
    return(TRUE)
  else
    return(FALSE)
}



remoter_repl_printer <- function()
{
  if (pbdenv$whoami == "remote")
  {
    pbdenv$status$shouldwarn <- FALSE
    return(invisible())
  }
  
  if (get.status(visible))
    cat(paste(get.status(ret), collapse="\n"), "\n")
  
  remoter_show_errors()
  remoter_show_warnings()
  
  return(invisible())
}



remoter_interrupt <- function(x)
{
#  pbdenv$status$remoter_prompt_active <- TRUE
  cat("interrupt\n")
  print(x)
}



remoter_warning <- function(warn)
{
  pbdenv$status$shouldwarn <- TRUE
  pbdenv$status$num_warnings <- pbdenv$status$num_warnings + 1
  
  pbdenv$status$warnings <- append(pbdenv$status$warnings, conditionMessage(warn))
  invokeRestart("muffleWarning")
  print(warn)
}



remoter_error <- function(err)
{
  msg <- err$message
  set.status(continuation, grepl(msg, pattern="unexpected end of input"))
  
  if (!get.status(continuation))
  {
    msg <- sub(x=msg, pattern=" in eval\\(expr, envir, enclos\\) ", replacement="")
    set.status(lasterror, paste0("Error: ", msg, "\n"))
  }
  
  return(invisible())
}



remoter_show_errors <- function()
{
  if (!is.null(get.status(lasterror)))
    cat(get.status(lasterror))
  
  invisible()
}



remoter_show_warnings <- function()
{
  warnings <- get.status(warnings)
  nwarnings <- length(warnings)
  
  if (!is.null(warnings) && pbdenv$status$shouldwarn)
  {
    if (nwarnings == 1)
    {
      cat("Warning message:\n")
      cat(warnings)
    }
    else if (nwarnings < 11)
    {
      cat("Warning messages:\n")
      for (i in 1:nwarnings)
      {
        w <- warnings[i]
        cat(paste0(i, ": ", w, "\n"))
      }
    }
    else
    {
      cat(paste("There were", nwarnings, "warnings (use warnings() to see them)"))
    }
    cat("\n")
  }
  
  pbdenv$status$shouldwarn <- FALSE
  
  invisible()
}



### TODO FIXME integrate with remoter_sanitize()
remoter_eval_filter_server <- function(msg)
{
  if (all(grepl(x=msg, pattern="^library\\(", perl=TRUE)))
  {
    msg <- paste0("
      tmp <- file(tempfile())
      sink(tmp, append=TRUE)
      sink(tmp, append=TRUE, type='message')\n", 
      msg, "\n
      sink()
      sink(type='message')
      cat(paste(readLines(tmp), collapse='\n'))
      unlink(tmp)
    ")
  }
  
  msg
}



remoter_eval <- function(input, whoami, env)
{
  set.status(continuation, FALSE)
  set.status(lasterror, NULL)
  
  if (whoami == "local")
  {
    send.socket(pbdenv$socket, data=input)
    
    ### Special cases
    if (all(grepl(x=input, pattern="^remoter_localize\\(", perl=TRUE)))
      eval(parse(text=input))
    else if (all(grepl(x=input, pattern="^ls.local\\(", perl=TRUE)))
      eval(parse(text=input))
    else if (all(grepl(x=input, pattern="^rm.local\\(", perl=TRUE)))
      eval(parse(text=input))
    else if (all(grepl(x=input, pattern="^eval.local\\(", perl=TRUE)))
      eval(parse(text=input))
    
    pbdenv$status <- receive.socket(pbdenv$socket)
    
#    remoter_show_errors()
#    remoter_show_warnings()
  }
  else if (whoami == "remote")
  {
    if (pbdenv$debug)
      cat("Awaiting message:  ")
    
    msg <- receive.socket(pbdenv$socket)
    
    if (pbdenv$debug)
      cat(msg, "\n")
    
    msg <- remoter_eval_filter_server(msg=msg)
    
    ret <- 
    withCallingHandlers(
      tryCatch({
          pbdenv$visible <- withVisible(eval(parse(text=msg), envir=env))
        }, interrupt=remoter_interrupt, error=remoter_error
      ), warning=remoter_warning
    )
    
    
    if (!is.null(ret))
    {
      set.status(visible, ret$visible)
      
      if (!ret$visible)
        set.status(ret, NULL)
      else
        set.status(ret, utils::capture.output(ret$value))
    }
    
    send.socket(pbdenv$socket, pbdenv$status)
    
  }
  else
    stop("bad 'whoami'")
}



#' remoter_exit
#' 
#' Exit the pbdR client/server.
#' 
#' @description
#' This function cleanly shuts down any pbdR servers which have been
#' spawned, as well as shutting down the client.  Failing to use
#' this function to shut down the client/server may cause unexpected
#' results.
#' 
#' @export
remoter_exit <- function()
{
  set.status(should_exit, TRUE)
  
  return(invisible())
}



remoter_check_password <- function()
{
  if (pbdenv$whoami == "local")
  {
    send.socket(pbdenv$socket, "")
    needpw <- receive.socket(pbdenv$socket)
    
    while (TRUE)
    {
      pw <- readline("enter the password:  ")
      send.socket(pbdenv$socket, pw)
      check <- receive.socket(pbdenv$socket)
      
      if (isTRUE(check))
        break
      else if (is.null(check))
        stop("Max attempts reached; killing server...")
      
      cat("Sorry, try again.\n")
    }
  }
  else if (pbdenv$whoami == "remote")
  {
    receive.socket(pbdenv$socket)
    
    if (is.null(pbdenv$password))
      send.socket(pbdenv$socket, FALSE)
    else
    {
      send.socket(pbdenv$socket, TRUE)
      
      attempts <- 2L
      while (TRUE)
      {
        pw <- receive.socket(pbdenv$socket)
        if (pw == pbdenv$password)
        {
          send.socket(pbdenv$socket, TRUE)
          break
        }
        else if (attempts <= pbdenv$maxattempts)
          send.socket(pbdenv$socket, FALSE)
        else
        {
          send.socket(pbdenv$socket, NULL)
          stop("Max attempts reached; killing self.")
        }
        
        attempts <- attempts + 1L
      }
    }
  }
}



remoter_repl_init <- function()
{
###  if (!get.status(remoter_prompt_active))
###    set.status(remoter_prompt_active, TRUE)
###  else
###  {
###    cat("The pbd repl is already running!\n")
###    return(FALSE)
###  }
  
  ### Initialize zmq
  if (pbdenv$whoami == "local")
  {
    pbdenv$context <- init.context()
    pbdenv$socket <- init.socket(pbdenv$context, "ZMQ_REQ")
    addr <- pbdZMQ::address(pbdenv$remote_addr, pbdenv$port)
    connect.socket(pbdenv$socket, addr)
    
    cat("\n")
  }
  else if (pbdenv$whoami == "remote")
  {
    ### Order very much matters!
    if (pbdenv$debug)
      cat("Hello! This is the server; please don't type things here!\n\n")
    
    ### client/server
    pbdenv$context <- init.context()
    pbdenv$socket <- init.socket(pbdenv$context, "ZMQ_REP")
    bind.socket(pbdenv$socket, paste0("tcp://*:", pbdenv$port))
  }
  
  
  remoter_check_password()
  
  return(TRUE)
}



remoter_repl <- function(env=sys.parent())
{
  ### FIXME needed?
  if (!interactive() && pbdenv$whoami == "local")
    stop("You should only use this interactively")
  
  if (!remoter_repl_init())
    return(invisible())
  
  
  ### the repl
  while (TRUE)
  {
    input <- character(0)
    set.status(continuation, FALSE)
    set.status(visible, FALSE)
    
    while (TRUE)
    {
      pbdenv$visible <- withVisible(invisible())
      input <- remoter_readline(input=input)
      
      remoter_eval(input=input, whoami=pbdenv$whoami, env=env)
      
      if (get.status(continuation)) next
      
      remoter_repl_printer()
      
      ### Should go after all other evals and handlers
      if (get.status(should_exit))
      {
        set.status(remoter_prompt_active, FALSE)
        set.status(should_exit, FALSE)
        return(invisible())
      }
      
      break
    }
  }
  
  set.status(remoter_prompt_active, FALSE)
  set.status(should_exit, FALSE)
  
  return(invisible())
}


