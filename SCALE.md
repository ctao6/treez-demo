# Scale: Keeping Current Orders Up to Date at Production Volume

Right now my approach reads the entire event log and rebuilds "current
state" from scratch every time. That's fine for a few thousand rows, but at
hundreds of millions of rows, reading everything on every run would get
slow and expensive fast. Additionally most of that data hasn't even changed since the
last run, so we can use a different approach to merge in new data.

**Here's how I'd approach it instead:**

1. **Only process new information:** I would keep track of the last event I've already
   processed. Each run, I'd only pull events that came in after that point,
   instead of scanning the whole history again.

2. **Update the current-state table in place:** Instead of recomputing "current orders" from zero every time, I'd keep it as a real table that persists between runs, and just update individual rows as new events come in. The approach would insert a row if the order is new, overwrite it if there's a more recent update.

3. **Make sure late-arriving updates don't cause problems:** Since older
   orders can still get updates, I'd only let a new event overwrite the
   stored version if its `event_seq` is actually newer than what's already
   there. That way, if an update for some old order shows up late, it still
   gets applied correctly. If the same event accidentally gets
   processed twice, it won't cause duplicate or incorrect changes.

4. **Sort the raw data by when it arrived:** Each run only has to
   look at a recent chunk of new events, not comb through the entire
   history every time. The current-orders table itself stays
   organized by order ID, so looking up and updating individual orders is
   fast.

At a high level, instead of solving "recompute everything" every run, the goal is
to solve "figure out what changed since last time, and apply just that". This scales
a lot better and handles the reality that updates to old orders can keep showing up 
at any point.
