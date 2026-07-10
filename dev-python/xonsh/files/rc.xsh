# xonsh config (web):
$PROMPT = '[{localtime}] {YELLOW}{env_name} {BOLD_BLUE}{user}@{hostname} {BOLD_GREEN}{cwd} {gitstatus}{RESET}\n@ '

# load plugins:
xontrib load coreutils
execx($(zoxide init xonsh), 'exec', __xonsh__.ctx, filename='zoxide')
