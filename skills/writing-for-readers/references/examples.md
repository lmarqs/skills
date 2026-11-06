# Examples

An example teaches by being concrete, and a reader learns everything in it, including the
parts the writer did not mean to teach. A detail added for color, a contrast added for
emphasis, a feature every example happens to share: the reader takes each one as part of the
lesson.

## Every detail is read as meant

Grice's cooperative principle describes what readers assume: the writer contributes "what is
required by the accepted purpose of the conversation", is "as informative as required", and
is relevant. So when a detail appears, the reader assumes it matters and looks for why.

Take an instruction meant to say "keep your keys with you":

> Put the keys in your pocket, not on the table.

Nobody mentioned a table. The reader now wonders what is wrong with the table, whether other
surfaces are fine, and whether the table is where the keys were. The contrast added a rule the
writer never intended. The example that teaches only the point:

> Keep the keys in your pocket.

Agent-written text does this often, because a contrast ("X, not Y") sounds emphatic. In
technical text it creates the same false rule:

> Store the token in an environment variable, not in a YAML file.

If the real rule is "never commit the token", this example teaches the wrong one: a reader may
commit a `.env` file and conclude they complied. Write the rule the example serves:

> Keep the token out of the repository: read it from the `API_TOKEN` environment variable,
> set in your shell or your CI secrets.

A contrast belongs in an example when the reader would otherwise do the contrasted thing.
"Run migrations with `make migrate`, not `rails db:migrate`" is right when the team's readers
reach for the Rails command by habit, and the text says why.

## A set of examples teaches its shared features

Anthropic's prompting guidance warns that examples should "vary enough that Claude doesn't
pick up unintended patterns", and the same holds for people. If every example of a valid
config uses the `us-east-1` region, readers infer the region is required. If every sample
request is a GET, readers infer the API does not take writes.

Test: list what all the examples share. Each shared feature is either part of the rule, and
the text says so, or it gets varied in at least one example.

## Names from the reader's world

Google's style guide: "Don't use unclear components like foo, bar, and baz in names", and
"Ensure that the name is applicable to the reader's environment." An example named
`invoice_total` tells the reader what kind of value goes there; `foo` tells them nothing and
makes them map it themselves. Use names the declared reader would use in their own work.

## One new fact per step

ASD-STE100 gives descriptive text one new fact per sentence and procedures one instruction
per sentence. An example that introduces the concept, a second concept and an edge case in
the same line makes the reader separate them. Split it, or show the edge case as its own
example.

## Building a minimal example

1. Write the point the example serves in one sentence.
2. Write the smallest concrete case where that point is visible.
3. Delete each clause, value and name in turn. If the point is still visible without it, it
   stays deleted.
4. For each remaining detail, ask what a reader would infer from it. Every inference is part
   of the point, or the detail changes.
5. For a set of examples, list their shared features and vary each one that is not part of the
   rule.

## Checks

- Each example has a stated point it serves.
- Every clause in the example survives the deletion test.
- Every contrast ("X, not Y") names something the reader would otherwise do, and says why.
- Features shared by all examples are either stated as the rule or varied.
- Names come from the reader's domain.
- Each example step introduces one new fact or instruction.
