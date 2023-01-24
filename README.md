# Template for Boku Payments Environments
![forthebadge](https://forthebadge.com/images/badges/60-percent-of-the-time-works-every-time.svg)
![forthebadge](https://forthebadge.com/images/badges/built-with-resentment.svg)
## Abstract

Unfortunately there is no one click environment builder yet, but this is the best you'll get! This repository is to be used in conjunction with the following guide: https://confluence.boku.com/display/ITO/AWS+New+Environment+Checklist

## Prerequisites

### Local PC Dependencies
* Terraform 1.0.0
* AWS IAM Authenticator https://docs.aws.amazon.com/eks/latest/userguide/install-aws-iam-authenticator.html
* AWS CLI configured. https://confluence.boku.com/display/ITO/Accessing+the+Kubernetes+Clusters
* SSH Key already created. Commit this to Lastpass!

Before starting, you will need to initialise a bucket for the Terraform state file to go. This repo **does not** do this for you. You'll need to go into the AWS console and create a bucket within the S3 menu. Once you have made a bucket (or chosen an existing one) you should include the variables in the `main.tf` file in the provider block.

After that, there are a list of dependencies you must do before running this which arre included in the Confluence link above. These include:
* Duo (optional)
* Puppet configs (mandatory, see guide)

## Building an Environment

Once that's done, **only** edit the values in the TFVars file. Do not dig any deeper as this is not required.

Initialise using the backend file in backend_configs:

    # Use the included script to check dependencies and manage the profile.
    ./tf-scripts/init.sh
    
    # If you like to live on the edge and manage your profile manually.
    terraform init -backend-config=backend_configs/backend.hcl

Now, run your favorite terraform commands per usual using the wrapper scripts.
    # Use the included scripts, it'll download secrets and manage your TF version.
    ./tf-scripts/plan.sh
    ./tf-scripts/apply.sh

If this is a production account, there is quite a lot of stuff to do after the Terraform has been completed.

https://confluence.boku.com/display/ITO/AWS+New+Environment+Checklist

## Limitations 
* S3 Buckets and IAM don't have a way of interacting. If you create a new S3 bucket that requires IAM permissions to be accessed, you'll need to edit the IAM module. There is no input facility for this at the moment.

* SNS is required in the Percona-Backup module. This is created, however the AWS API doesn't support email subscriptions. You'll need to manually add the db-monitoring@boku.com subscription to the topic manually after it's created. Make sure you tell someone on the DB Team so they can accept the invite.

* VPC Peering is optional, and you may want to include this if your environment

* You'll need to do this in 2 parts. Mainly because the way TF works, it is unable to class the kubectl config file as a dependency for other modules. So it can't wait for this file.

## Troubleshooting
**init.sh doesn't work, bucket not found.**
This could be two reasons. If you've just created the S3 bucket, give it a minute. AWS takes it's time on this one and the API may not respond straight away with the newly created bucket. Otherwise, if you've previously run an init, but then changed your mind on where the state file should be stored, the error is because your existing .terraform folder contains a reference to the old bucket. You'll need to wipe out that folder and run init again.

**EKS hangs on creation.** This is because the TF expects to be able to hit the Kubernetes API. If the Module or your config specifics that the health endpoint is private, it'll just stall and die. Either run TF from a server within the cluster or set to public.

**User-Data changes aren't sticking!** Well my friend, you've run into some fun tech debt. When the initial build of USW2 happened, it was done from a Windows PC. Which uses CRLF for line breaks, instead of LF in Unix. Unfortunately this meant that when Terraform base64'd the user-data.sh files it always resulted in a mismatch. We were too far gone so we've added the following to most instances. 

```
   lifecycle {
        ignore_changes = ["user-data"]
        create_before_destroy = true
    }
```
In most cases, changing user-data will result in the destruction of the instance. Since you're doing this, you can remove this statement, apply, then add it back in.

**Static IPs are already in use.**  AWS may say this if you are cycling resources. The original IP isn't "released" for a few momentts after the deleted resource is completely gone. You will probably just have to run apply twice and you'll be sorted. Alternatively, a load balancer may have sniped your IP address if you are only applying a little at a time. Use the following commands to track it down.
> aws ec2 describe-network-interfaces --filters Name=addresses.private-ip-address,Values=<IP_ADDRESS> --region <REGION> --profile <AWS_PROFILE>

Then use the following command to kill it.
> terraform taint path.to.resource

Once you apply again, TF will destroy the item that sniped your IP. However you will likely need to run apply twice, the resource will be deleted, but the IP address probably won't be released fast enough for your other resource to spin up. Just waitt for it to fail, confirm the new resource has a different IP, then run apply again.

**Flux wants to install a lot of shit.** The Flux provider and the associated helm operator use kubectl via shell to manage everything. If the kubeconfig you have on your PC doesn't point to the correct environment, then you need to make sure this is fixed! Otherwise you'll contaminate the state file.

**Destroying takes forever with EKS or VPC resources.** There are a couple of reasons this might be the case. If your VPC Is not destroying or because subnets are not being destroyed, check for rogue load balancers or servers in EC2. If a user has launched a load balancer this will prevent the subnet being deleted. Go in and look for any that are occupying the subnets in question.

If your EKS cluster is not being destroyed and being hung up on the Flux namespace, this is because Flux uninstall is a bit gross. Run a `kubectl get namespaces` and confirm that flux-system is listed as "terminating." If so, it'll remain like this and you'll need to help it along. In the `.tf-scripts/` folder there is a file called `flux-ns-remove.sh`. Run the first command, then remove `kubernetes` from the `finalizers[]` array. Then run the second command.

If your VPC is not being destroyed at the end, there is likely another dependency here. Go into the UI and delete it manually. For some reason the UI is able to take away some of the dependent resources (like security groups that are usually automatically created) whereas the API/CLI/Terraform cannot.