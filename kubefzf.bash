
# Requires: pee (package moreutils)

kctx () {
    # Set current context ($KUBECONFIG).
    if [ "$1" = "-e" ] ; then
        kubectl config use-context "$2"
    else
      kubectl config get-contexts  | cut -c11- \
          | pee 'head -1' 'tail -n+2 | sort' \
          | fzf +m --no-sort --header-lines=1 --height=40% -n1 --prompt="context > " \
          | awk '{print $1}' \
          | xargs --no-run-if-empty \
              kubectl config use-context
      # cut -c11- : column 'CURRENT' must be removed; counts as 1 field when 
      #       has '*' and 0 fields otherwise.
      # pee: used to sort bypassing the first line.
    fi
}

kns () {
    # Set default namespace in current context ($KUBECONFIG).
    if [ "$1" = "-e" ] ; then
        kubectl config set-context "$(kubectl config current-context)" \
            --namespace "$2"
    else
      kubectl get ns \
          | fzf --header-lines=1 --height=40% --prompt="$(kubectl config current-context):namespace > " \
          | awk '{print $1}' \
          | xargs --no-run-if-empty \
              kubectl config set-context "$(kubectl config current-context)" --namespace
    fi
}


_kubernetes_resources_names () {
    cat <<.
pods                        po
deployments                 deploy
statefulsets                sts
daemonsets                  ds
services                    svc
persistentvolumeclaims      pvc
persistentvolumes           pv
configmaps                  cm
secrets
endpoints                   ep
events                      ev
ingresses                   ing
namespaces                  ns
nodes                       no
jobs
cronjobs
certificatesigningrequests  csr
clusterrolebindings
clusterroles
clusters
componentstatuses           cs
controllerrevisions
customresourcedefinition    crd
horizontalpodautoscalers    hpa
limitranges                 limits
networkpolicies             netpol
poddisruptionbudgets        pdb
podpreset
podsecuritypolicies         psp
podtemplates
replicasets                 rs
replicationcontrollers      rc
resourcequotas              quota
rolebindings
roles
serviceaccounts             sa
storageclasses
all
.

}


k8set () {
    local resource namespace context out pre post

    # trim="${READLINE_LINE%% }"    # trim spaces at end of line, just in case

    resource=$(_kubernetes_resources_names \
        | fzf --no-sort --height=40% --prompt="${READLINE_LINE}" \
        | awk '{ if (NF==2) print $2 ; else print $1}')

    # Read namespace from $KUBECONFIG file.
    context=$(kubectl config current-context)
    namespace=$(kubectl config view -o jsonpath="{.contexts[?(.name==\"${context}\")].context.namespace}")
    # Alternative: pass namespace on current readline, preceded by '-n'.
    # namespace=$(echo $READLINE_LINE | sed 's/.* -n //;s/ .*//')
    case "${READLINE_LINE}" in
        *" log "*|*" logs "*|*" exec "*)
            prefix="" ;;
        *)
            prefix="${resource}/" ;;
    esac


    out=$(kubectl get -n "${namespace}" "${resource}" \
        | fzf -m --header-lines=1 --height=40% --prompt="${READLINE_LINE} ${prefix}" \
        | awk -vRES="${prefix}" -vORS=' ' '{print RES $1}')
    # Insert into current line.
    pre_line="${READLINE_LINE:0:$READLINE_POINT}"
    post_line="${READLINE_LINE:$READLINE_POINT}"
    READLINE_LINE="${pre_line}${out}${post_line}"
    READLINE_POINT=$(( ${#pre_line} + ${#out} ))
}

# Run k8set on Alt-k.
bind -x '"\ek":"k8set"'
