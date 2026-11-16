# graceDR release checklist

Follow these steps in order for every CRAN submission.

1. Start from an up-to-date `main`.

   ```bash
   git fetch origin
   git switch main
   git pull --ff-only
   ```

2. Check the name and the current CRAN version. Expect 404 for a first release. If 200, the
   new version must be higher than the CRAN version.

   ```bash
   curl -sL -o /dev/null -w "%{http_code}" https://CRAN.R-project.org/package=graceDR
   ```

3. In a worktree, set the version and write the entry in `NEWS.md`. Use `'patch'` instead of
   `'minor'` for a fix release.

   ```bash
   Rscript -e "usethis::use_version('minor')"
   ```

4. Run the local checks (check, URLs, spelling). Fix every ERROR, WARNING and NOTE except
   "New submission".

   ```bash
   make cran-local
   ```

5. Ask James, then run the win-builder check. It uploads the package and emails the
   maintainer. Wait for the email and paste its result into the PR.

   ```bash
   make cran-win-devel
   ```

6. Run the R-hub checks after the card "CRAN: rhub setup" is merged. Wait for the three runs
   to finish in GitHub Actions.

   ```bash
   make cran-rhub
   ```

7. Copy `dev/cran-comments.template.md` to `cran-comments.md` and fill each placeholder with
   real results. Never write a result that was not observed.

   ```bash
   cp dev/cran-comments.template.md cran-comments.md
   ```

8. Open the PR, wait for CI, wait for James's approval, then squash-merge.

9. Tag the merge commit and release. Never move or delete a pushed tag. If a fix is needed,
   bump the patch version and start over at step 3.

   ```bash
   git tag v<version>
   git push origin v<version>
   gh release create v<version> --generate-notes
   ```

10. Run the preflight check (card "CRAN: submission preflight").

    ```bash
    make cran-preflight
    ```

11. James runs the submission from the tagged commit and answers its prompts, then clicks the
    confirmation link that CRAN emails to the maintainer address in `DESCRIPTION`.

    ```bash
    Rscript -e "devtools::submit_cran()"
    ```

12. When CRAN replies, record the outcome as a comment on the Jira card. If CRAN asks for
    changes, go to step 3 with a patch version.

13. After acceptance, run the card "JSS article: install from CRAN".
