from xonsh.xoreutils._which import which, WhichError
from xonsh.built_ins import XSH

# xonsh config (web):
$PROMPT = '[{localtime}] {YELLOW}{env_name} {BOLD_BLUE}{user}@{hostname} {BOLD_GREEN}{cwd} {gitstatus}{RESET}\n@ '

# always show errors:
$XONSH_PROMPT_SHOW_SUBPROC_ERROR = True

# fzf, will get initizlied when load:
XSH.env['fzf_history_binding'] = "c-r"  # Ctrl+R
XSH.env['fzf_ssh_binding'] = "c-s"  # Ctrl+S
XSH.env['fzf_file_binding'] = "c-t"  # Ctrl+T
XSH.env['fzf_dir_binding'] = "c-g"  # Ctrl+G

# load plugins:
xontrib load coreutils
xontrib load fzf-completions
execx($(zoxide init xonsh), 'exec', __xonsh__.ctx, filename='zoxide')

# shortcuts:
aliases["ll"] = ["ls", "-la"]
aliases[".."] = ["cd", ".."]

# auto ls, not using on_chdir as it may affects not only the interactive shell:
__rcxsh_auto_ls_lastpwd = ""
@events.on_post_prompt
def _auto_ls() -> None:
    global __rcxsh_auto_ls_lastpwd
    if __rcxsh_auto_ls_lastpwd == $PWD:
        return
    __rcxsh_auto_ls_lastpwd = $PWD
    $[ls]

# up to directory:
@aliases.register("up")
@aliases.return_command
def _up(args):
    path = $PWD
    while path != "":
        path, base = path.rsplit("/", maxsplit=1)
        if args[0] in base:
            return ["cd", f"{path}/{base}"]
    raise

# unprefix for gentoo:
@aliases.register("unprefix")
@aliases.return_command
def _unprefix(args):
    eprefix = which("emerge").rsplit("/", maxsplit=1)[0]
    path = os.pathsep.join(filter(lambda p: not p.startswith(eprefix), $PATH))
    return ["env", f"PATH={path}", *args]
