overlay() {
    A=$(pwd)
    B=/tmp/overlay-$(echo -n $A | sha1sum | head -c 16)
    rm -rf $B && mkdir $B && mkdir $B/w && mkdir $B/u
    echo "trap 'rm -rf $B/w $B/s' EXIT && cd .. && mount -t overlay overlay -o lowerdir=$A,upperdir=$B/u,workdir=$B/w $A && cd $A && [ -z '$@' ] && unshare -U bash --init-file <(echo \"PS1='\e[0;31m[overlay]\e[m\w> '\") || (echo '$@' > $B/c && unshare -U bash $B/c)" >$B/s
    unshare -rm bash "$B/s"
}
