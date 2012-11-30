Dictionary structure
====================

Dictionary file ends with .dic extension.

It consists of word definitions.

Word definition looks like

    N    100    cat/a     Pl

Where:

* `N` means word type (A - adjective, D - adverb, N - noun, O - other, V - verb)
* `100` is the word frequency (can be any integer greater or equal 0)
* `cat` is the word text; if it includes spaces, the text must be surrounded by double quotes
* `/a` is the inflexion scheme (a)
* `Pl` includes word properties (see below)

You can enter words of different types in whatever order you want. It is legal (although not advised) to mix words of different types. Usually you would group them: first nouns, then adjectives and so on.

The hash sign (#) marks begin of a comment.

Word properties
==============

Adjective
-----------

* `NOT_AS_OBJ`

  Makes the adjective never be chosen as adjective object. Example:

        A 100 this NOT_AS_OBJ

  prevents appearing things like "cat becomes these".

* `ATTR(prep,case)`

  Makes the adjective always be linked with a noun in given case and proposition. Example:

        N 100 memory
        A 100 lost ATTR(in,2)

  may produce "lost in memory"

Noun
----

* `m`

  `f`

  `n`

  Marks the noun gender: male, female or neuter. Defaults to male if not specified.

* nan

  Marks the noun as non-animated (important for inflection in Slavic languages).

* `NO_ADJ`

  Makes the noun never take an adjective.

* `OBJ_FREQ(f)`

* `ONLY_OBJ`

* `ONLY_SUBJ`

* `PERSON(p)`

* SUFFIX(suf)

  Always adds a suffix (may contain spaces, so consist of many words) after the noun.
  While the noun is a subject to inflexion, the suffix never is.
  Example:

        N 100 dog SUFFIX(on a lead)

  may produce "dog on a lead"

Verb
----

* ADJ

  Marks the verb as taking adjective object. Example:

        N 100 he
        V 100 become/1 ADJ
        A 100 lost

  may produce "he becomes lost"

* INF

  INF(prep)

  Marks the verb as taking infinitive object, optionally by specifying a preposition. Example:

        N 100 he
        V 100 listen
        V 100 must INF

  may produce "he must listen"

* OBJ(case)

  OBJ(prep,case)

  Marks the verb as taking noun as an object, optionally linked with a preposition. Example:

        N 100 ich/0
        V 100 spielen/1 OBJ(mit,3)

  may produce "spiel mit mir", while:

        N 100 ich/0
        V 100 hören/2 OBJ(4)

  may produce "hör mich".

* REFLEX

  RELEXIVE

  Marks the verb as reflexive. Example:

        N 100 Stadt f
        V 100 befinden/1 REFLEX

  may produce "die Stadt befindet sich"

* SUFFIX(suf)

  Always adds a suffix (may contain spaces, so consist of many words) after the verb. Example:

        N 100 she
        V 100 go/1 SUFFIX(nuts)

  may produce "she goes nuts"
