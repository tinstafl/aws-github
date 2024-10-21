# aws-github

shell scripts to assist creating the required resources that enable github to communicate with aws via oidc and iam authentication

### handshake

```shell
# create oidc provider, iam role, and attach policy to role
handshake/create.sh -a <aws_account_id> -g <github_org> -r <repository_name> [-o <oidc_audience>] [-n <role_name>] [-p <oidc_provider_arn>] [-w <aws_region>]

# update iam role policy to include a new organization/repository combination
handshake/extend.sh -r <aws_region> -n <role_name> -o <github_org> -p <repository_name>

# delete oidc provider, detach policy, delete iam role
handshake/delete.sh -a <aws_account_id> [-r <role_name>] [-w <aws_region>]
```

### codeconnection

```shell
# create github codeconnection arn for org/repo
codeconnection/create.sh -a <aws_account_id> -g <github_org> -r <repository_name> [-w <aws_region>] [-c <connection_name>]

# delete github codeconnection arn for org/repo
codeconnection/delete.sh -a <aws_account_id> -g <github_org> -r <repository_name> [-w <aws_region>] [-c <connection_name>]
```

<small>ref</small>

+ https://github.com/aws-actions/configure-aws-credentials
