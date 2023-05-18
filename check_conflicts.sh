#!/bin/bash

echo "Checking Conflicts..."

# Variables initialization
CONFLICT_PR_AMOUNT=0

# check_pulls.sh exports two variables FOUND_PR_NUMBERS and FOUND_PR_AMOUNT
# if FOUND_PR_NUMBERS is empty, do nothing, else start checking for conflicts
if [[ -z "${FOUND_PR_NUMBERS}" ]]
then
    echo "No pulls to scan for conflicts..."
else
    # Bash doesn't exports arrays, so we have to convert it from string
    readarray -t pr_array <<<"$FOUND_PR_NUMBERS"

    # Cloning the repository to allow for branch comparisons
    echo "[DEBUG] PWD: $(pwd)"
    gh repo clone "${OWNER}/${REPOSITORY}" || true
    cd "${REPOSITORY}" || exit
    echo "[DEBUG] REPOSITORY PWD: $(pwd)"

    # Checkout the current PR and get its branch name
    gh pr checkout "${PR_NUMBER}"
    PR_BRANCH_NAME=$(git branch --show-current)

    echo "[DEBUG] PR_BRANCH_NAME: ${PR_BRANCH_NAME}"


    # Modification

    # Loop through the array of PR numbers to check if they conflict with the
    # current pr by having git attempt an auto merge between the two branches.
    for pr in "${pr_array[@]}"
    do
        echo "[DEBUG] Checking conflicts on PR: $pr..."

        gh pr checkout "$pr"
        COMPARE_BRANCH_NAME=$(git branch --show-current)

        echo "[DEBUG] COMPARE_BRANCH_NAME: ${COMPARE_BRANCH_NAME}"

        # This is required when running the git merge, even though no commit is
        # going to be made, git still needs an identity. (TODO: Find a better way)
        git config user.email "pr-tracker@github.com"
        git config user.name "PR Tracker"

        # Dry run of git merge
        MERGE_DRY_RUN=$(git merge "$PR_BRANCH_NAME" --no-commit --no-ff "$COMPARE_BRANCH_NAME" || true)

        # When a conflict is detected, git enters a halt state and displays an
        # message, using grep we can confirm that it was really a failure.
        if echo "${MERGE_DRY_RUN}" | grep -q "did not work\|failed"; then
            echo "[DEBUG] Conflict found!"
            # Increment the amount of conflicts
            ((CONFLICT_PR_AMOUNT++))
            # Cleanup of the merge operation
            git merge --abort || true
            git reset --merge
        else
            echo "[DEBUG] No conflicts found!"
            # Cleanup of the merge operation
            git merge --abort || true
            git reset --merge
        fi
    done

    # Go back to the root (pr-tracker) files
    cd ..
    echo "[DEBUG] PWD: $(pwd)"
fi

# By default this condition is false and it won't run, unless
# a conflict has been detected, and incremented the variable count
if [[ "${CONFLICT_PR_AMOUNT}" -gt 0 ]]; then

    # Debug logs
    echo "[DEBUG] CONFLICT_PR_AMOUNT: ${CONFLICT_PR_AMOUNT}"

    # Exports external variables to be used with other scripts
    export CONFLICT_PR_AMOUNT="${CONFLICT_PR_AMOUNT}"
fi