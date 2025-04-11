#import "@preview/touying-flow:1.1.0":*
#import "@preview/pinit:0.2.2":*
// #import "@preview/commute:0.2.0":*
#show: flow-theme.with(
  aspect-ratio: "16-9",
  footer: self => self.info.title,
  footer-alt: self => self.info.subtitle,
  navigation: "mini-slides",
  primary:rgb("#543795"),//rgb(0,108,57),//rgb("#006c39"),
  secondary:rgb("#a38acb"),//rgb(161,63,61),//rgb("#a13f3d"),
  // text-font: ("Libertinus Serif"),
  // text-size: 20pt,
  // code-font: ("Jetbrains Mono NL","PingFang SC"),
  // code-size: 16pt,

  config-info(
    title: [Hierarchical Navigable Small World graph],
    subtitle: [],
    author: [董若扬],
    date: datetime.today(),
    institution: [ADSL, USTC],
  ),
  // config-common(show-notes-on-second-screen: right),
)

#title-slide()

= #smallcaps("Introduction")

== HNSW

#side-by-side(columns: (8fr,5fr))[
Hierarchical Navigable Small World (HNSW)
- _State-of-the-art_ method for _in-memory_ _graph_ indexing  

Design inspired by:
- NSW (Navigable Small World)  
- Probability Skip List
][
#figure(
  image("img/hnsw.png"),
  caption:[HNSW]
)
]



#place(bottom)[
#align(right)[#underline[#text(fill: gradient.linear(..color.map.flare))[#link("https://www.pinecone.io/learn/series/faiss/hnsw/")[Some images sourced from Faiss: The Missing Manual
]]]]  
#align(right)[#underline[#text(fill: gradient.linear(..color.map.crest))[#link("https://arxiv.org/pdf/1603.09320")[(IEEE TPAMI 2018) Malkov Y A, Yashunin D A. Efficient and robust approximate nearest neighbor search using hierarchical navigable small world graphs.]]]]]

== NSW

#side-by-side(columns: (3fr,2fr))[
*NSW Key Idea:  *
- Uses proximity graph  
- Builds short and long-distance links  

*Search Process:  *
- Starts at a preset entry point  
- Moves to nodes closer to the query  

*Drawbacks: * 
- High search complexity  
- Get stuck in local minima at low-degree nodes

][
  #figure(
  image("img/nsw.png",width: 73%),
  caption:[NSW]
)#figure(
  image("img/nswsearch.png",width: 73%),
  caption:[low-degree and high-degree nodes]
)
]
#slide[
#side-by-side(columns: (3fr,2fr))[
*NSW Construction:* 
- For a new point: connect M nearest points 
  - _Early stage_: mostly "highway" links  
  - _Later stage_: mostly nearest neighbor links  
- NSW naturally has long-distance edges  

*ANNS Time Complexity: * 
- Sum of degrees of visited nodes  
- No pruning in NSW
  - high degree, high complexity

*HNSW Design:*  
- Uses layers  
- Trades space for speed
][
#figure(
  image("img/nsgconstruction.jpg",width: 80%),
  caption:[NSW Construction]
)
]  
]

== Probability Skip List

*Builds multi-level linked lists*  
#side-by-side[- Top layer: skips many nodes][- Lower layers: skips fewer nodes]
  


#figure(
  image("img/skip.png",width: 80%),
  caption:[Probability Skip List]
)

HNSW design inherits layered structure:
#side-by-side[- High layers: long edges (fast search)][- Low layers: short edges (accurate search)]
= #smallcaps("Algorithm")

== [Alg.1] Construction

#side-by-side(columns: (3fr,2fr))[
*HNSW Insertion: * 
- Each point picks a layer based on probability  
- Added to that layer and all below  

*Example:*
- Probability Table: [0.96, 0.03, 0.0009...]  
- Random number: 0.98  
- _0.98 > 0.96:_ move up one layer, 0.98 - 0.96 = 0.02  
- _0.02 < 0.03:_ stays in layer 1

][
#figure(
  image("img/insert.png",width: 120%),
  caption:[Insert]
)

]

#slide[#side-by-side(columns: (3fr,2fr))[
#side-by-side(columns: (2fr,3fr))[
$q$: Point to insert
][
$WW$: Nearest Neighbor Set
]
Starts from top layer:

*Phase 1: Before Target Layer*
  - From entry point: find point closest to $q$
  - Use it as next layer’s entry
*Phase 2: At Target Layer:*
  - From entry point: search [Alg.2] for _efConstruction_ points closest to $q$, save to $WW$
  - From $WW$: pick [Alg.3] M neighbors for $q$
  - Build two-way links, check if neighbors need pruning
  - set $WW$ as next Layer's entry points
][
#figure(
  image("img/construction.jpg",width: 80%),
  caption:[HNSW Construction]
)
]]

== [Alg.2] Search

#side-by-side(columns: (3fr,2fr))[
#side-by-side[
- q: Query point
][
- ep: Entry point (set)
]
- ef: Number of neighbors to search
#side-by-side[
$VV$: Visited set
][
$CC$: Candidate set
][
$WW$:  Neighbor Set
]

while $CC$ is not empty:
- Pick $c$: closest point to $q$ from $CC$
- Pick $f$: farthest point to $q$ from $WW$
- if $D(c,q) > D(f,q)$: stop
- Check all neighbors $e$ of $c$
  - if $D(e,q) < D(f,q)$ _or_ $|WW| < e f$
    #side-by-side[- $CC$.add($e$)][- $WW$.add($e$)]
][
#figure(
  image("img/search.jpg",width: 80%),
  caption:[Search]
)
]

== [Alg.3] Choosing neighbors

#side-by-side(columns: (2fr,1fr))[
#side-by-side[
- $CC$: Candidate set
][
- $RR$: Result set
][
- $DD$: Discarded set
]
*Ⅰ. Simple :*
- Pick the M nearest neighbors from $WW$

*Ⅱ. Heuristic：*
- Simple selection can split clusters, leaving isolated islands
- _Phase 1_
  - Pick point closest to $q$ each time
  - if closer to $q$ than all in $RR$: add to $RR$
  - else: add to $DD$
- _Phase 2_
  - Fill $RR$ up to M From $DD$

][
#figure(
  image("img/choose.png",width: 90%),
  caption:[Select the graph neighbors for two isolated clusters.]
)
]

= #smallcaps("Improvement")

== Combined with IVF

#side-by-side(columns: (3fr,2fr))[
Combines _cluster-based_ and _graph-based_ index
- IVF clustering
- Builds HNSW index on cluster centroids

Small clusters allow exhaustive search after locating

// Still takes up _significant memory_
][
#figure(
  image("img/ivfhnsw.png"),
  caption:[IVF-HNSW]
)
]
