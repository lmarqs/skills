# Diagrams: which one answers which question

A diagram exists to answer a reader's question. Pick it from the question, draw it at one level of
zoom, embed it as Mermaid so the document keeps standing alone, and caption it with its type, its
level, and the requirement IDs it answers. Two are required in the Design step: one static (structure)
and one dynamic (behaviour over time). Add others only when the decision turns on what they show.

## Contents

1. [Picker](#picker)
2. [Rules that apply to every diagram](#rules-that-apply-to-every-diagram)
3. [Skeletons](#skeletons)

## Picker

| The reader asks | Diagram | Level | Static or dynamic |
| --- | --- | --- | --- |
| What is this system, who uses it, what does it talk to? | C4 context | Level 1: the system as one box, its users and external systems | Static |
| What are the deployable parts and how do they communicate? | C4 container | Level 2: applications, services, data stores inside the boundary | Static |
| How is one container built inside? | C4 component | Level 3: the modules of one container | Static |
| In what order do the parts talk during one use case? | Sequence | The containers or components involved in that one flow | Dynamic |
| What decisions does a request go through? | Flowchart | One operation, with its branches | Dynamic |
| What are the entities and how do they relate? | Entity-relationship | The tables or aggregates the decision touches | Static (data) |
| What states can a thing be in, and what moves it? | State | One entity or one workflow | Dynamic |
| Where does each part run, and on what? | Deployment | Infrastructure nodes and the containers placed on them | Static (runtime) |

Choose the deployment view when the decision is about runtime, scaling or cost. Choose the
entity-relationship view when it is about the data model, ownership or migration. Choose a state
diagram when the decision hinges on a lifecycle (an order, a document, a job). Otherwise the context or
container view plus one sequence is enough.

## Rules that apply to every diagram

- **One level of zoom per diagram** (C4). A picture that shows the system's users and also the tables
  inside one service is two diagrams drawn on top of each other, and the reader cannot tell which
  boxes are peers.
- **Every box is named with the same name the text uses.** One name per concept holds in pictures
  too. If the glossary says "the search service", the box says "Search service".
- **Every arrow carries a verb or a protocol**: "reads", "publishes order events", "HTTPS/JSON". An
  unlabeled arrow is a claim with no content.
- **The caption names the type, the level, and the requirement IDs** the diagram answers, so a reader
  can check that every requirement is met by something and every component serves one:

  ```
  *Figure 2. C4 container diagram. Answers F1, F3, N1, N3.*
  ```

- **Embed, do not link.** A diagram that lives in another tool is a forward reference, and the document
  stops standing alone. If the real drawing exists elsewhere, the Mermaid version is the one the
  argument uses, and the external file is listed under Sources.
- **Show what changes.** In a forward-looking document, mark the components being added and the ones
  being removed (a style or a label such as "new" and "to be retired"), so the reader sees the
  decision, not just the end state.

## Skeletons

Mermaid `flowchart` with subgraphs is used for the C4 levels because it renders everywhere Mermaid does.
Mermaid's dedicated C4 syntax exists but renders inconsistently across tools; use it only if the team
already does.

### C4 context (level 1)

```mermaid
flowchart LR
    user["Role: what they do with the system"]
    ext["External system<br/>(what it provides)"]
    subgraph boundary["Organization boundary"]
        sys["The system being decided<br/>(one sentence of purpose)"]
    end
    user -->|"does X through"| sys
    sys -->|"reads / writes Y via protocol"| ext
```

*Figure 1. C4 context diagram. Answers F1, F2.*

### C4 container (level 2)

```mermaid
flowchart TB
    client["Web app / mobile app<br/>(who uses it)"]
    subgraph system["The system"]
        api["API service<br/>(responsibility)"]
        worker["Background worker<br/>(responsibility)"]
        db[("Primary store<br/>(what it holds)")]
        cache[("Cache<br/>(what it holds, TTL)")]
    end
    legacy["Component being retired"]:::retire
    client -->|"HTTPS/JSON"| api
    api -->|"reads"| cache
    api -->|"reads / writes"| db
    worker -->|"consumes events"| db
    api -.->|"replaces"| legacy
    classDef retire stroke-dasharray: 5 5
```

*Figure 2. C4 container diagram. Answers F1, F3, N1, N3.*

### C4 component (level 3)

```mermaid
flowchart LR
    subgraph api["API service"]
        ctrl["Request handler<br/>(validates, parameterises input)"]
        rank["Ranking module<br/>(applies business rules)"]
        repo["Repository<br/>(queries the store)"]
    end
    ctrl --> rank --> repo
```

*Figure 3. C4 component diagram of the API service. Answers F4, F5.*

### Sequence (one use case)

```mermaid
sequenceDiagram
    actor R as Role
    participant C as Client
    participant S as Service
    participant D as Store
    R->>C: performs the action (F1)
    C->>S: request (parameters)
    S->>S: validate and parameterise the input (F5)
    S->>D: query
    D-->>S: rows
    S-->>C: response, paginated (N1 measured here)
    C-->>R: observable result
```

*Figure 4. Sequence diagram, container level, for the "search by term" scenario. Answers F1, F5, N1.*

### Flowchart (one operation's decisions)

```mermaid
flowchart TD
    A["Request arrives"] --> B{"Valid input?"}
    B -- no --> E["400 with error code"]
    B -- yes --> C{"In cache?"}
    C -- yes --> R["Return cached"]
    C -- no --> D["Query store (timeout T)"]
    D --> F{"Found?"}
    F -- no --> N["404; caller decides its fallback"]
    F -- yes --> W["Write to cache"] --> R
```

*Figure 5. Resolution flow for one lookup. Answers F3, N1, N2.*

### Entity-relationship (data view)

```mermaid
erDiagram
    ORDER ||--|{ ORDER_ITEM : contains
    ORDER }o--|| CUSTOMER : placed_by
    ORDER {
        uuid id PK
        uuid customer_id FK
        text status
        timestamptz created_at
    }
    ORDER_ITEM {
        uuid id PK
        uuid order_id FK
        int quantity
    }
```

*Figure 6. Entity-relationship diagram of the tables the decision touches. Answers F2, N4.*

### State (lifecycle)

```mermaid
stateDiagram-v2
    [*] --> Pending
    Pending --> Paid : payment confirmed
    Pending --> Cancelled : timeout (T minutes)
    Paid --> Fulfilled : all items shipped
    Paid --> Refunded : refund approved
    Fulfilled --> [*]
    Cancelled --> [*]
    Refunded --> [*]
```

*Figure 7. State diagram of an order. Answers F6, N5.*

### Deployment (runtime view)

```mermaid
flowchart TB
    subgraph region["Cloud region"]
        subgraph edge["Edge"]
            cdn["CDN / API gateway<br/>(auth, rate limit)"]
        end
        subgraph compute["Compute"]
            fn["Function or container<br/>(the API service)"]
        end
        subgraph data["Data"]
            db[("Managed database<br/>(size, replicas)")]
            cache[("Cache cluster")]
        end
    end
    users["Clients"] --> cdn --> fn
    fn --> cache
    fn --> db
```

*Figure 8. Deployment diagram. Answers N1, N3, N4.*
