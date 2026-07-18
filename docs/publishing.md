# Publishing

## Release flow

`dev` is the integration branch and `main` is production. Release candidates use
SemVer prerelease versions (`0.2.0-rc.1`, `0.2.0-rc.2`, …) and ship through a
`dev → main` pull request labeled `release`.

## Verify without publishing

```sh
npm test
npm run pack:check
```

For a full local artifact smoke test:

```sh
artifact="$(npm pack)"
scratch="$(mktemp -d)"
npm install --global --prefix "$scratch" "$artifact"
"$scratch/bin/agentic-undo-redo" --version
rm "$artifact"
rm -rf "$scratch"
```

## Publish an RC

Publishing is deliberately manual:

1. Merge the green `dev → main` release PR.
2. Tag the merge commit: `git tag v0.2.0-rc.1 && git push origin v0.2.0-rc.1`.
3. Create a GitHub prerelease from that tag using the matching changelog section.
4. Run `npm publish --tag next` from a clean checkout of the tag.

Never publish a prerelease on npm's `latest` tag. Later candidates increment the
RC number. Promote a tested candidate by releasing the final `0.2.0` version
through the same `dev → main` flow and publishing it with the default `latest`
tag.
