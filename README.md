# Nix Knowledge Sharing thingy

This was originally written some time ago, but should still be relevant. Actual
presentation source is [here](./presentation.md).

It's public domain ([CC0](./LICENSE.md)). Note that the resulting presentation
might not be. Check out the licenses for the google-fonts at least.

`nix build` will build `presentation.pdf`, `speaker-notes.pdf` and `article.html`.

You can also build only some of them by entering `nix develop` and then doing
`make <thing>`.

Also available in `nix develop` is `make autoreload` which automatically
rebuilds `presentation.pdf` whenever you change `presentation.md`. You can then
open the presentation in some auto-reloading PDF viewer and get live updates of
it as you add stuff.

BTW, I encourage you to add more things about Nix in general and/or add things
that are specific to your `$WORK`, and then share some Nix love yourself. You
can also make PRs with stuff you're willing to forfeit copyright for.