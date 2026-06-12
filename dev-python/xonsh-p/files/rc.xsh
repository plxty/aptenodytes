# xonsh config (web):
xontrib load coreutils
$PROMPT = '[{localtime}] {YELLOW}{env_name} {BOLD_BLUE}{user}@{hostname} {BOLD_GREEN}{cwd} {gitstatus}{RESET}\n@ '
