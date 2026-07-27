# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A published Terraform module (`delivops/ecs-service/aws`) that provisions an ECS
service. There is no application code, no test suite, and no way to run anything
against AWS from this repo — verification is `fmt`, `validate`, and reasoning.

## Commands

Three **independent Terraform roots**. A change to the module's variables can
break an example without breaking the module, so all three must be checked. CI
runs exactly these:

```bash
terraform fmt -check -recursive          # whole repo

terraform init -backend=false && terraform validate                      # module
cd examples     && terraform init -backend=false && terraform validate    # examples
cd examples/gpu && terraform init -backend=false && terraform validate    # separate root
```

CI pins Terraform 1.9.8; `versions.tf` requires `>= 1.9`.

## Verification without AWS

There are no credentials here, so `terraform plan` against the real module fails
on the AWS provider before reaching anything useful, and `terraform validate`
does **not** load variable values — variable `validation` blocks never fire under
it. Neither proves much on its own.

What works: build a **provider-free root** in a scratch directory that extracts
the expressions under test *verbatim from the shipped files*, then drive it with
`terraform plan` (exit code) or `terraform apply` + `terraform output -json`
(values). Extracting rather than retyping means the harness cannot drift from the
code. When testing a fix, run the harness against the **old** expression too — a
harness that passes both ways proves nothing.

`null_resource` is useful as a stand-in for a not-yet-created resource: it is a
legacy SDKv2 provider, so its computed attributes are *unrefined* unknowns at
plan time, matching `aws_iam_role` and most of the AWS provider. `terraform_data`
is not equivalent — its unknowns carry a not-null refinement, so `!= null`
collapses to a known `true` and bugs of that class do not reproduce.

## Architecture

### The task definition is write-once

`aws_ecs_task_definition` carries `lifecycle { ignore_changes = all }`, and the
service ignores `task_definition`. The module registers one revision to bootstrap
the service and then never touches it again — the running revision is owned by
the CI pipeline (`delivops/ecs-deploy-action`).

Consequence: `ecs_task_cpu`, `ecs_task_memory`, `container_name`,
`container_image` and `network_mode` **only affect the first revision**. Changing
them on an existing service yields a clean plan and no change. Anything added to
the container definition inherits this, so a new task-definition input is close
to inert for existing services and needs saying so in its description.

`desired_count` is likewise in the service's `ignore_changes`, so an external
autoscaler owns the running count. This module manages no autoscaling.

### SSM parameters are the contract with CI

`ssm.tf` publishes the role ARNs at predictable paths for the deploy pipeline to
read:

```
/ecs/<cluster>/<service>/task-role
/ecs/<cluster>/<service>/execution-role
```

These are a **public interface**, not an implementation detail. Renaming or
removing one destroys the parameter on apply and breaks deploys the moment the
pipeline next runs. Tags are deliberately not published — the service is tagged
and `propagate_tags = "SERVICE"` carries them to tasks.

### Task role vs execution role

`task_role` and `execution_role` are symmetric objects (`create`, `arn`, `name`,
`inline_policy`, `attach_policies`); each is created here, supplied by ARN, or
absent, and `create`/`arn` are mutually exclusive. They default differently on
purpose: the task role starts empty because only the application knows what it
needs, while a created execution role gets `AmazonECSTaskExecutionRolePolicy`
because that part is identical everywhere. `AmazonECSTaskExecutionRolePolicy`
does **not** cover secrets — `ssm:GetParameters` / `secretsmanager:GetSecretValue`
must be added via `execution_role.inline_policy`.

## Two invariants that have each caused a released bug

### `count` and `for_each` must derive from configuration

Deriving a `count` from a resource attribute — including `arn != null` — makes
the count unknown at plan time and Terraform refuses to plan
(`Invalid count argument`). This is unescapable from a clean state: the plan
fails, so the resource is never created, so the attribute stays unknown. It
shipped in v1.1.1 and made `role.create = true` unusable.

Every `count`/`for_each` in the module currently derives from `var.*`. Keep it
that way. Where a "does this exist" boolean is needed, compute it from inputs
(`local.has_task_role`) rather than testing the resolved ARN.

### A guard and everything that dereferences it must match

`data.aws_lb` instances are dereferenced from four places: both
`aws_route53_record` resources and both DNS-related outputs. When those guards
drifted apart, configurations that satisfied one but not the other failed with
`Invalid index` (v1.1.3 — the NLB path, where the ARN arrives as `nlb_arn`
because the module creates the listener itself, and any config setting the
Route53 fields without a listener).

`locals.tf` now resolves the ARN once (`main_lb_arn`, `additional_lb_arns`,
`additional_lb_arns_resolved`, `create_main_route53_record`) and every consumer
shares it. Adding a consumer means using those locals, not writing a new guard.
`terraform validate` cannot catch this class of bug.

## Releases

Merging to `main` cuts a tag automatically from the **squash-commit message**
(`mathieudutour/github-tag-action`).

- `fix:` / `refactor:` / `docs:` / `chore:` → patch
- `feat:` → minor
- `feat!:` or a `BREAKING CHANGE:` footer → major

**The default is patch.** A breaking change merged without `!` or the footer
ships as a patch and consumers on `~>` pick it up automatically. GitHub pre-fills
the squash subject from the PR title, so the PR title must carry `feat!:` — put
the footer in the commit body as well.

Changes confined to `README.md`, `.github/**` or `examples/**` cut no release
(`paths-ignore` in `git-tag.yaml`). A root `CHANGELOG.md` change **does**.

## Docs

`terraform-docs` regenerates the input/output tables between the `BEGIN_TF_DOCS`
markers in `README.md` and **pushes a commit back to the PR branch**. Edit
variable and output `description` fields, not the tables; prose outside the
markers is hand-maintained.

That bot commit becomes the PR head, and workflow runs triggered by it land in
`action_required` rather than executing — so the final head of a PR that changes
the module's public surface carries no validated result. Pre-existing, and worth
knowing before concluding a PR is green.

## Conventions

- Comments explain non-obvious constraints, not narration. No comments recording
  what the code used to do or why a change was made — that belongs in the commit
  message. No comments describing something's absence.
- Use typed attribute access (`var.service_connect.appProtocol`), not `lookup()`,
  on the typed object variables.
- Build JSON with `jsonencode` over an HCL structure. Hand-built JSON strings
  silently corrupt on any value containing a quote or backslash.
- The ECR repository comes from `terraform-aws-modules/ecr` v2.3.0. Check that
  module's own variable defaults before exposing a passthrough — several already
  match what an existing repository has, and passing a literal where it expects
  `null` can add a `ForceNew` block that proposes a replacement.
