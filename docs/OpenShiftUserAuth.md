# OpenShift User Authentication
An initial OpenShift 4.x install has the default **kubeadmin** user 

Ideally we should always configure an initial [Identity Provider](https://docs.openshift.com/container-platform/4.1/authentication/identity_providers/configuring-htpasswd-identity-provider.html#identity-provider-creating-htpasswd-file-linux_configuring-htpasswd-identity-provider) such as htpasswd.


For this demo we've supplied our standard htpasswd entry for the admin user

I you want to override this with your own password simply type
```
# Make sure you're logged in as the kubeadmin user
oc whoami

# Then create our new htpasswd file
htpasswd -c -B  demo.admin.htpasswd admin

# Finally update the Auth configuration in OpenShift
./ocp_htpass.sh
```



