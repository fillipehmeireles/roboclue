import std/httpclient
import std/strutils
import std/asyncdispatch
import std/os
import std/strformat
import std/parseopt
const
  B_MAGENTA = "\e[95m"
  B_GREEN = "\e[92m"
  B_RED = "\e[91m"
  B_CYAN = "\e[96m"
  B_BLUE = "\e[94m"
  RESET = "\e[0m"
  PROGRAM_NAME = "roboclue"


proc banner() =
  echo fmt"{B_CYAN}      {PROGRAM_NAME} {RESET} - {B_GREEN} Fast robots.txt audit {RESET}"
  echo fmt"Version:{B_GREEN} 2.0 {RESET}"
  echo fmt"Author:{B_MAGENTA}  Nong Hoang Tu {RESET}"
  echo fmt"Contributors: {B_MAGENTA} Fillipe Meireles; PalinuroSec {RESET}"
  echo fmt"Github:{B_BLUE}  https://github.com/ParrotSec/roboclue {RESET}"
  echo fmt"License:{B_GREEN} GPL-2"


proc usage() =
  echo fmt"{B_RED}Usage: {B_CYAN}{PROGRAM_NAME} {RESET}[{B_BLUE}-t=delayTime{RESET}] [{B_MAGENTA}-u=https://example.com or -f=/path/to/url_list{RESET}]"


proc help() =
  banner()
  usage()


proc formatURL(url: string): string =
  result = url
  if not url.startsWith("http"):
    result = "http://" & result
  if not url.endsWith("/") and not url.endsWith("robots.txt"):
    result &= "/"
  return result


proc addRobotToUrl(url: string): string =
  result = url
  if not url.endsWith("/"):
    result &= "/"
  if not url.endsWith("robots.txt"):
    result &= "robots.txt"
  return result


proc checkSleepTime(t: string): int =
  try:
    result = parseInt(t)
    if result >= 0:
      return result
    else:
      return 0
  except:
    return 0

proc checkSitemap(line: string) =
  if line.startsWith("Sitemap:"):
    let url = line.split(": ")[1]
    echo fmt"{B_CYAN} [*] Sitemap captured: {url} {RESET}"

proc checkRobot(url: string, delay = 0) =
  try:
    let
      client = newAsyncHttpClient()
    defer: client.close()
    echo fmt"{B_CYAN} [*] Checking robots.txt {RESET}"
    
    let 
      targetUrl = addRobotToUrl(url)
    let
      resp = waitfor client.get(targetUrl)
    if resp.code != Http200:
      echo B_RED, targetUrl, " ", resp.code, RESET
      return

    echo B_GREEN, targetUrl, " ", resp.code, RESET
    echo B_CYAN, "[*] Checking URL from robots.txt", RESET
    for line in waitfor(resp.body).split("\n"):
      checkSitemap(line)
      if line.startsWith("Disallow:") or line.startsWith("Allow:"):
        if ": /" in line:
          let
            path = line.split(": /")[1].replace("\n", "").replace("\r", "")
          if path != "":
            let
              checkBranch = if not path.startsWith("http"): url.replace("robots.txt", "") & path else: path
              respcheckBranch = waitfor client.get(checkBranch)
            if respcheckBranch.status.startsWith("200"):
              echo B_GREEN, checkBranch, " ", respcheckBranch.status, RESET
            elif respcheckBranch.status.startsWith("30"):
              echo B_CYAN, checkBranch, " ", respcheckBranch.status, RESET
            elif respcheckBranch.status.startsWith("404"):
              echo B_RED, checkBranch, " ", respcheckBranch.status, RESET
            else:
              echo B_MAGENTA, checkBranch, " ", respcheckBranch.status, RESET
            if delay > 0:
              sleep(delay * 1000)
  except OSError as e:
    echo fmt"{B_RED} [!] Error on request. Error code: OSError({e.errorCode}) {RESET}"


proc cli() =
  var
    url: string
    filePath: string
    delay: string
  for kind, key, value in getOpt():
    case kind:
    of cmdArgument:
      discard
    of cmdLongOption, cmdShortOption:
      case key:
      of "h", "help":
        help()
        quit()
      of "u","url":
        url = value
      of "t":
        delay = value
      of "f", "file":
        filePath = value
      else:
        echo fmt"{B_RED} Unknown option: {key} {RESET}"
        usage()
    of cmdEnd:
      discard
  if filePath == "" and url == "":
    echo B_RED, "[x] No URL was provided!", RESET
    usage()
  if filePath != "" and url == "":
    if fileExists(filePath):
      for line in lines(filePath):
        if not isEmptyOrWhitespace(line):
          checkRobot(formatURL(line), checkSleepTime(delay))
    else:
      echo B_RED, "[x] File not found! ", filePath, RESET
  elif url != "":
    checkRobot(formatURL(url), checkSleepTime(delay))

when isMainModule:
  cli()
