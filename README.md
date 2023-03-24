# ![nf-core/actions-runners](images/nfcore-actionsrunners_logo.png#gh-light-mode-only) ![nf-core/actions-runners](images/nfcore-actionsrunners_logo_dark.png#gh-dark-mode-only)

# Introduction

nf-core uses GitHub Actions to run continuous integration (CI) tests for every change on every repository.
As we get bigger, the number of those tests increases and can start to overwhelm our free allowance at GitHub (20 concurrent jobs).
This gets very annoying, as people need to wait quite a long time for jobs to run on their pull requests before they can be merged.
The problem is particularly acute during events such as hackathons.

To get around this, we can create custom [self-hosteed GitHub Actions runners](https://docs.github.com/en/actions/hosting-your-own-runners/about-self-hosted-runners) to provide more compute power for the CI jobs.
We do this on the nf-core AWS account, which is kindly funded by credits provided by AWS for our project.

Runners are created at the organisation level and share the same tags as the default GitHub runners. This means that all jobs may run on them, and they simply help to drain the job queue.

# Instructions

> We first set up AWS runners in the October 2022 hackathon.
> This was done by @apeltzer. The initial discussion is documented in [this GitHub issue](https://github.com/nf-core/tools/issues/1940#issuecomment-1276032624).
> This repo is a continuation of that work.

## Creating the EC2 instance

> **Note**
> This is only required for setting up things from start - there is also an AMI set up with the ID `ami-043ce0b3c3257bb96 ` (accessible for core members) to just boot up an arbitrary EC2 instance that already connects to the self-hosted backend of GitHub for nf-core repositories.

Steps:

1. Use `ubuntu` latest for EC2 instance, boot up machine with sufficient local storage (256GB is enough)

2. Start machine, log in as standard user

3. Install required software and set up groups using the [`install_ec2.sh` script](install_ec.sh).

4. Go to the [nf-core runners settings page](https://github.com/organizations/nf-core/settings/actions/runners) (only accessible to core team members). Select instructions on how to set up runners by copying the code line by line and executing it :wink:

    > **Warning**
    > Make sure that you run the `./configure ...` step in a way that you add the label `ubuntu-latest` so that any nf-core pipeline repository can run their jobs on the created runner.  Otherwise your runner will not take any jobs from repositories in nf-core, thus being not particularly useful! :wink: You will be asked whether you want to add labels interactively, so this is easy!

4. Manually set up service to autostart when machine boots as documented [here](https://docs.github.com/en/actions/hosting-your-own-runners/configuring-the-self-hosted-runner-application-as-a-service)
    ```bash
    sudo ./svc.sh install
    sudo ./svc.sh start
    ```

5. Check if the runner is up and running and taking up jobs on the [nf-core runners settings page](https://github.com/organizations/nf-core/settings/actions/runners).
