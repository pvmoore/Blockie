# Mermaid Examples

```mermaid
    info
```

## Orientations
 - TD = Top Down
 - LR = Left to Right
 - BT = Bottom to Top
 - RL = Right to Left

## Flow Chart

```mermaid
flowchart TD
    A-->B
    A-->C["Thing"]
    B-->D
    C:::red-->D["Apple
           Pear
           Orange
    "]
    D-->E("E")
    E-->F([F])
    F-->G[[G]]
    G-->H[(Data)]
    H-->I((Circle))
    I-->J>Blah]
    J-->K{Question}
    K-- Yes -->L[\Yes\]
    K-- No -->M[/No/]
    M-. Test .->N{{N}}
    N==>O[\O/]
    O== Text ==>P[/P\]
    P-->Q(((Q)))
    Q-->R-->S 
    R@{shape:braces, label:"Rrrr" }
    click A "https://github.com/pvmoore/Blockie/blob/master/readme.md"
    
    classDef red stroke:#fff,stroke-width:1px,fill:#aa8,color:#000,font-size:16px;
    class A,B red
```

```mermaid
flowchart LR
    %% comment
    subgraph "One **Thing**"
        direction LR
        A[Start] --> B[Process 1]
        B --> C[Process **Two**]
        C --> D[End]
    end
    subgraph two
        direction TB
        D --> E[Process 3]
        E --> F[Process 4]
    end
    direction TB
    F --> G[Exit]
```

## Sequence Diagram

```mermaid
sequenceDiagram
    participant Client
    participant Server
    Client->>Server: Register user
    activate Server
    Server-->>Client: User already exists.
    deactivate Server

```

## Class Diagram

```mermaid
classDiagram
    class Animal {
        +name: string
        +age: int
        +makeSound(): void
    }
    class Dog {
        +breed: string
        +bark(): void
    }
    class Cat {
        +color: string
        +meow(): void
    }
    class Bird {
        +species: string
        +fly(): void
    }
    class Food {
        +name: string
        +type: string
    }
    Animal <|-- Dog
    Animal <|-- Cat
    Dog -- Food
    Cat ..> Food
    Bird -- Food
```

## Pie Chart

```mermaid
pie
    title Distribution of Expenses
    "Food" : 60
    "Rent" : 15
    "Entertainment" : 10
    "Savings" : 15

```
