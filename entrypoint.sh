MY=(
    [ROLE]=www
    [RUN_AS]=root

    [NO_STDOUT_REDIR]="${NO_STDOUT_REDIR:-}"
    [NO_STDERR_REDIR]="${NO_STDERR_REDIR:-}"
)

passthrough_unless "nginx" "$@"

echo 'daemon off;' >> /etc/nginx/nginx.conf
if have_global vhosts; then
    {
        # wait endlessly for 1st write in the background
        inotifywait -qqe close_write "${OUR[VHOSTS]}"

        # if it happens set up vhosts
        rm -r /etc/nginx/sites-enabled
        ln -s "${OUR[VHOSTS]}" /etc/nginx/sites-enabled
        nginx -s reload

        while inotifywait -qqe close_write "${OUR[VHOSTS]}"; do
            # nth write, just reload nginx so it picks up newcomers
            nginx -s reload
            # this loop stays alive as a child process even when the parent
            # shell exec()s to something else
        done
    } &
fi

[[ -n "${MY[NO_STDOUT_REDIR]}" ]] || ln -sf /dev/stdout /var/log/nginx/access.log
[[ -n "${MY[NO_STDERR_REDIR]}" ]] || ln -sf /dev/stderr /var/log/nginx/error.log

# nginx drops privileges after acquiring port
run "$@"
