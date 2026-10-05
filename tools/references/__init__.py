"""Reference checking: do the paths and tasks a tree mentions resolve?

A repository's prose names files and pixi tasks. When one is renamed, moved,
or never existed, the reference rots quietly: nothing imports a sentence. This
package reads every tracked text file, collects backticked path tokens and
`pixi run <task>` phrases, and reports the ones that resolve to nothing.

What counts as resolving is the consumer's policy, not this package's: which
suffixes to read, which paths to skip, which executables pixi may run
directly, and which references live in another repository and are attested
rather than resolved. The package supplies the engine and the file listing;
the consumer supplies the `Policy`.

It decides nothing about the code it reads. An unresolved reference is a
report, and what a consumer does about it is the consumer's rule.
"""
