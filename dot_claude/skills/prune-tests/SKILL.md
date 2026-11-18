---
name: prune-tests
description: Have a fresh sub-agent audit the tests a branch adds or changes and flag the low-value ones (mock assertions, restated implementation, duplicates, framework tests), then delete the ones the user picks. Use after finishing a branch, or when the user says "prune the tests", "drop the low-value tests", "are these tests worth keeping", or "trim the tests".
argument-hint: "[base-branch]"
---

# Prune tests

Find the tests on this branch that are not worth keeping, and delete the ones the user
agrees with. Only tests the branch adds or changes are in scope. A test that exists on the
base branch unchanged is never touched.

## Step 1: Determine scope

The base is `$ARGUMENTS` if given. Otherwise it is the open PR's base branch
(`gh pr view --json baseRefName`), or with no PR, the default branch
(`git symbolic-ref refs/remotes/origin/HEAD`).

List the test files and test cases added or changed in the diff against that base. If there
are none, say so and stop.

## Step 2: Audit

Launch one general-purpose sub-agent, foreground. A fresh reader is the point: the session
that wrote the tests is the worst judge of them. Give it the base branch and the list from
step 1, and tell it to report only, not to edit anything.

It reads each test together with the code it covers and lists the low-value ones, each with
its file, test name, and a one-line reason. Low value means:

- it asserts on mocks or call counts rather than behavior
- it restates the implementation, so it cannot fail unless the test is edited too
- it duplicates what another test already covers
- it tests the language, the framework, or the type system
- it is a snapshot or smoke test with no assertion that could catch a regression

A test that is the only coverage of a behavior, an edge case, or a bug fix is not low value,
however plain it looks. The sub-agent lists those separately as "weak but sole coverage".

## Step 3: Adjudicate and report

Read each test the sub-agent listed and make your own call. Drop any you disagree with from
the list and say why.

Report the remaining candidates numbered for easy reference (1., 2., 3.), each with its
reason, then the "weak but sole coverage" tests as a separate list of ones worth
strengthening rather than deleting.

Report only. Do not delete anything until the user says which items to drop.

## Step 4: Delete

Delete the tests the user picked, along with helpers, fixtures, and imports only they used.
Delete a test file when nothing is left in it.

Run the test suite for the affected files to confirm what remains still passes. Leave the
change uncommitted unless the user asks otherwise.
