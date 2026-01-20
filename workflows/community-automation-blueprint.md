# Community Content Automation Architecture
## n8n Workflow Blueprint for Human-Like AI Content Generation

---

## Executive Summary

This blueprint outlines a sophisticated multi-workflow n8n system designed to automate community content posting while maintaining authentic human-like characteristics. The architecture consists of **5 interconnected workflows** that work together to generate, humanize, schedule, and post content through multiple seed accounts.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        MASTER ORCHESTRATOR WORKFLOW                         │
│                         (Scheduled: Random intervals)                        │
└──────────────────────────────────┬──────────────────────────────────────────┘
                                   │
           ┌───────────────────────┼───────────────────────┐
           ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  WORKFLOW 1:    │    │  WORKFLOW 2:    │    │  WORKFLOW 3:    │
│  Content Topic  │───▶│  Persona-Based  │───▶│  Humanization   │
│  Generator      │    │  AI Drafting    │    │  Filter         │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                                       │
                       ┌───────────────────────────────┤
                       ▼                               ▼
           ┌─────────────────┐             ┌─────────────────┐
           │  WORKFLOW 4:    │             │  WORKFLOW 5:    │
           │  Smart Scheduler│             │  Engagement     │
           │  & Poster       │             │  Simulator      │
           └─────────────────┘             └─────────────────┘
```

---

## WORKFLOW 1: Dynamic Content Topic Generator

### Purpose
Aggregate diverse content sources and generate unique, trending topics relevant to the entrepreneurship/tech community.

### Node Architecture

```
┌──────────────┐   ┌──────────────┐   ┌──────────────┐
│ Schedule     │──▶│ Parallel     │──▶│ Merge &      │
│ Trigger      │   │ Source Fetch │   │ Deduplicate  │
└──────────────┘   └──────────────┘   └──────────────┘
                          │                   │
    ┌─────────────────────┼───────────────────┘
    ▼                     ▼
┌──────────┐    ┌──────────────┐    ┌──────────────┐
│ RSS Feeds│    │ News APIs   │    │ Reddit/HN    │
│ (Tech)   │    │ (NewsAPI)   │    │ Trending     │
└──────────┘    └──────────────┘    └──────────────┘
                          │
                          ▼
              ┌─────────────────────┐
              │ Topic Enrichment    │
              │ (AI: Add angles,    │
              │  controversy, hooks)│
              └─────────────────────┘
                          │
                          ▼
              ┌─────────────────────┐
              │ Store to Database   │
              │ (Topic Queue)       │
              └─────────────────────┘
```

### Key Nodes Configuration

#### 1.1 Multi-Source Fetcher (Parallel Execution)

```javascript
// Code Node: Source Aggregator
const sources = [
  { type: 'rss', url: 'https://techcrunch.com/feed/', category: 'startup' },
  { type: 'rss', url: 'https://feeds.feedburner.com/ycombinator', category: 'hn' },
  { type: 'rss', url: 'https://entrepreneurship.mit.edu/feed/', category: 'education' },
  { type: 'api', name: 'newsapi', query: 'startup OR entrepreneur OR tech funding' },
  { type: 'api', name: 'reddit', subreddit: 'startups+entrepreneur+technology' }
];

// Randomize source selection (don't always use all)
const selectedSources = sources
  .sort(() => Math.random() - 0.5)
  .slice(0, Math.floor(Math.random() * 3) + 2);

return selectedSources.map(source => ({ json: source }));
```

#### 1.2 Topic Enrichment Prompt

```javascript
// AI Node System Prompt
const systemPrompt = `You are a content strategist for a tech/startup community.

Given this article/topic, generate 3 UNIQUE discussion angles:

1. CONTRARIAN: A perspective that challenges conventional wisdom
2. PRACTICAL: A "how would you apply this" discussion starter
3. PERSONAL: A "share your experience with X" community prompt

For each angle, provide:
- headline (compelling, slightly informal)
- hook (first sentence that draws readers in)
- contentType: "article" | "discussion" | "question" | "hot-take"
- controversyLevel: 1-5 (higher = more engagement potential)
- complexity: "beginner" | "intermediate" | "advanced"

Output as JSON array.`;
```

---

## WORKFLOW 2: Persona-Based AI Content Drafting

### Purpose
Select appropriate seed account personas and generate content matching their unique voice and style.

### Persona Database Structure

```javascript
const PERSONAS = {
  "alex_founder": {
    id: "alex_founder",
    name: "Alex Chen",
    background: "3x founder, 2 exits, currently building AI startup",
    tone: "direct, occasionally sarcastic, uses founder jargon",
    writingStyle: {
      sentenceLength: "short-to-medium",
      paragraphLength: "2-4 sentences",
      usesEmoji: false,
      usesHashtags: "rarely",
      capitalization: "standard",
      punctuationQuirks: ["...often uses ellipses", "occasional ALL CAPS for emphasis"],
      commonPhrases: ["here's the thing", "unpopular opinion", "learned this the hard way"],
      typoFrequency: 0.02, // 2% chance of deliberate typo
      editPatterns: ["sometimes adds (edited) at end", "crosses out words with ~~strikethrough~~"]
    },
    topicExpertise: ["fundraising", "product-market fit", "hiring", "B2B SaaS"],
    postingHabits: {
      preferredTimes: ["early-morning", "late-night"], // "insomnia poster"
      avgPostLength: { min: 150, max: 400 },
      postsPerWeek: { min: 3, max: 7 }
    },
    engagementStyle: "responds to comments quickly, debates respectfully"
  },

  "maria_vc": {
    id: "maria_vc",
    name: "Maria Rodriguez",
    background: "Partner at seed-stage VC, ex-operator",
    tone: "analytical, supportive, asks probing questions",
    writingStyle: {
      sentenceLength: "medium-to-long",
      paragraphLength: "3-5 sentences",
      usesEmoji: true, // sparingly: rocket, chart, lightbulb
      usesHashtags: "never",
      capitalization: "standard",
      punctuationQuirks: ["uses em-dashes liberally", "numbered lists"],
      commonPhrases: ["what I look for", "pattern I'm seeing", "founders often miss"],
      typoFrequency: 0.01,
      editPatterns: ["rarely edits"]
    },
    topicExpertise: ["fundraising", "pitch decks", "market sizing", "founder psychology"],
    postingHabits: {
      preferredTimes: ["business-hours"],
      avgPostLength: { min: 200, max: 600 },
      postsPerWeek: { min: 2, max: 4 }
    },
    engagementStyle: "thoughtful replies, often asks follow-up questions"
  },

  "dev_sam": {
    id: "dev_sam",
    name: "Sam Park",
    background: "Senior engineer turned technical co-founder",
    tone: "casual, technical, self-deprecating humor",
    writingStyle: {
      sentenceLength: "variable",
      paragraphLength: "1-3 sentences",
      usesEmoji: true, // developer emojis: skull, fire, eyes
      usesHashtags: "occasionally",
      capitalization: "often lowercase",
      punctuationQuirks: ["lol", "tbh", "ngl", "uses code blocks"],
      commonPhrases: ["not gonna lie", "hot take", "@ me", "skill issue"],
      typoFrequency: 0.03, // more casual about typos
      editPatterns: ["edits to add 'edit: clarification'"]
    },
    topicExpertise: ["technical architecture", "developer tools", "hiring engineers", "tech debt"],
    postingHabits: {
      preferredTimes: ["late-night", "weekend"],
      avgPostLength: { min: 50, max: 300 },
      postsPerWeek: { min: 5, max: 12 }
    },
    engagementStyle: "quick witty responses, shares memes, debates technical points"
  },

  "lisa_growth": {
    id: "lisa_growth",
    name: "Lisa Thompson",
    background: "Head of Growth, scaled 3 startups from 0 to Series B",
    tone: "data-driven, enthusiastic, shares frameworks",
    writingStyle: {
      sentenceLength: "medium",
      paragraphLength: "structured with headers/bullets",
      usesEmoji: true, // business emojis: chart, target, money
      usesHashtags: "strategically",
      capitalization: "Title Case for headers",
      punctuationQuirks: ["numbered frameworks", "before/after comparisons"],
      commonPhrases: ["the playbook", "here's exactly how", "thread incoming"],
      typoFrequency: 0.005, // very polished
      editPatterns: ["adds updates at bottom"]
    },
    topicExpertise: ["growth hacking", "marketing", "analytics", "user acquisition"],
    postingHabits: {
      preferredTimes: ["morning", "lunch"],
      avgPostLength: { min: 300, max: 800 },
      postsPerWeek: { min: 2, max: 5 }
    },
    engagementStyle: "shares additional resources, connects people"
  },

  "newbie_jordan": {
    id: "newbie_jordan",
    name: "Jordan Lee",
    background: "First-time founder, building in public",
    tone: "curious, humble, shares learnings transparently",
    writingStyle: {
      sentenceLength: "medium",
      paragraphLength: "2-4 sentences",
      usesEmoji: true, // expressive
      usesHashtags: "frequently",
      capitalization: "standard",
      punctuationQuirks: ["question marks", "exclamation points (not excessive)"],
      commonPhrases: ["just learned", "anyone else?", "what am I missing", "week X update"],
      typoFrequency: 0.025,
      editPatterns: ["edits based on community feedback"]
    },
    topicExpertise: ["learning journey", "early-stage struggles", "tool comparisons"],
    postingHabits: {
      preferredTimes: ["any"],
      avgPostLength: { min: 100, max: 350 },
      postsPerWeek: { min: 4, max: 8 }
    },
    engagementStyle: "very responsive, thanks people, asks for advice"
  }
};
```

### Node Architecture

```
┌──────────────┐   ┌──────────────┐   ┌──────────────┐
│ Receive      │──▶│ Persona      │──▶│ Build        │
│ Topic        │   │ Matcher      │   │ Prompt       │
└──────────────┘   └──────────────┘   └──────────────┘
                                             │
                                             ▼
                                   ┌──────────────────┐
                                   │ AI Content       │
                                   │ Generator        │
                                   │ (Claude/GPT)     │
                                   └──────────────────┘
                                             │
                                             ▼
                                   ┌──────────────────┐
                                   │ Output with      │
                                   │ Persona Metadata │
                                   └──────────────────┘
```

### 2.1 Persona Matcher Logic

```javascript
// Code Node: Intelligent Persona Selection
const topic = $json.topic;
const contentType = $json.contentType;
const complexity = $json.complexity;
const recentPosters = $json.recentPosters || []; // Avoid same persona posting consecutively

// Get all personas
const personas = Object.values(PERSONAS);

// Filter by topic expertise match
const expertiseMatch = personas.filter(p =>
  p.topicExpertise.some(exp =>
    topic.toLowerCase().includes(exp.toLowerCase())
  )
);

// Filter out recent posters (last 3 posts shouldn't be same persona)
const availablePersonas = (expertiseMatch.length > 0 ? expertiseMatch : personas)
  .filter(p => !recentPosters.slice(-3).includes(p.id));

// Weight by content type suitability
const weighted = availablePersonas.map(p => {
  let weight = 1;

  if (contentType === 'hot-take' && p.tone.includes('sarcastic')) weight += 2;
  if (contentType === 'question' && p.tone.includes('curious')) weight += 2;
  if (contentType === 'article' && p.writingStyle.paragraphLength.includes('structured')) weight += 2;
  if (complexity === 'beginner' && p.id === 'newbie_jordan') weight += 3;
  if (complexity === 'advanced' && p.topicExpertise.length > 3) weight += 2;

  return { persona: p, weight };
});

// Weighted random selection
const totalWeight = weighted.reduce((sum, w) => sum + w.weight, 0);
let random = Math.random() * totalWeight;

for (const { persona, weight } of weighted) {
  random -= weight;
  if (random <= 0) {
    return [{ json: { ...topic, selectedPersona: persona } }];
  }
}

return [{ json: { ...topic, selectedPersona: weighted[0].persona } }];
```

### 2.2 Dynamic Prompt Builder

```javascript
// Code Node: Build Persona-Specific Prompt
const { topic, hook, contentType, selectedPersona } = $json;
const p = selectedPersona;

const prompt = `
You are writing as ${p.name}, a community member with this background: ${p.background}

YOUR VOICE & STYLE:
- Tone: ${p.tone}
- Sentence length: ${p.writingStyle.sentenceLength}
- Paragraph style: ${p.writingStyle.paragraphLength}
- Common phrases you naturally use: ${p.writingStyle.commonPhrases.join(', ')}
- Emoji usage: ${p.writingStyle.usesEmoji ? 'Yes, sparingly and naturally' : 'No emojis'}
- Hashtag usage: ${p.writingStyle.usesHashtags}
- Punctuation quirks: ${p.writingStyle.punctuationQuirks.join('; ')}

CONTENT REQUIREMENTS:
- Topic: ${topic}
- Opening hook: ${hook}
- Content type: ${contentType}
- Target length: ${p.postingHabits.avgPostLength.min}-${p.postingHabits.avgPostLength.max} words

CRITICAL HUMANIZATION RULES:
1. DO NOT be generic or write like marketing copy
2. Include a personal anecdote or specific example from "your experience"
3. Reference specific numbers, dates, or details (make them realistic)
4. Include ONE of these natural imperfections:
   - A minor tangent that you bring back
   - A self-correction mid-thought
   - An aside in parentheses
   - A rhetorical question
5. End with something that invites response (question, controversial statement, or open loop)
6. Vary your sentence structure - not every sentence should be the same length
7. Use contractions naturally (don't → don't, cannot → can't)
8. If appropriate, reference a current event or trend (vaguely, don't date it)

WHAT TO AVOID:
- Starting with "I think" or "In my opinion" (too generic)
- Perfect grammar and structure throughout (too polished)
- Bullet points unless that's your style (${p.id === 'lisa_growth' ? 'OK for you' : 'avoid'})
- Corporate buzzwords without irony
- Concluding with "What do you think?" (overused)

Write the post now. Output ONLY the post content, nothing else.
`;

return [{ json: { prompt, persona: p, topic, contentType } }];
```

---

## WORKFLOW 3: Humanization Filter

### Purpose
Post-process AI-generated content to add authentic human imperfections and variations.

### Node Architecture

```
┌──────────────┐   ┌──────────────┐   ┌──────────────┐
│ Receive      │──▶│ Typo         │──▶│ Formatting   │
│ AI Draft     │   │ Injector     │   │ Variator     │
└──────────────┘   └──────────────┘   └──────────────┘
                                             │
                                             ▼
┌──────────────┐   ┌──────────────┐   ┌──────────────┐
│ Output       │◀──│ AI Detection │◀──│ Rhythm       │
│ Final        │   │ Check        │   │ Breaker      │
└──────────────┘   └──────────────┘   └──────────────┘
```

### 3.1 Typo Injector

```javascript
// Code Node: Intelligent Typo Injection
const content = $json.content;
const persona = $json.persona;
const typoFrequency = persona.writingStyle.typoFrequency;

// Common human typos (based on keyboard proximity and common mistakes)
const typoPatterns = [
  { find: /\bthe\b/g, replace: 'teh', prob: 0.3 },
  { find: /\byou\b/g, replace: 'yuo', prob: 0.2 },
  { find: /\band\b/g, replace: 'adn', prob: 0.2 },
  { find: /\bjust\b/g, replace: 'jsut', prob: 0.3 },
  { find: /\bwith\b/g, replace: 'wiht', prob: 0.2 },
  { find: /\bthat\b/g, replace: 'taht', prob: 0.2 },
  { find: /\bwere\b/g, replace: 'where', prob: 0.4 }, // common confusion
  { find: /\btheir\b/g, replace: 'thier', prob: 0.3 },
  { find: /\breally\b/g, replace: 'realy', prob: 0.4 },
  { find: /\bdefinitely\b/g, replace: 'definately', prob: 0.5 },
];

// Double letter mistakes
const doubleMistakes = [
  { find: /ll/g, replace: 'l', prob: 0.1 },
  { find: /ss/g, replace: 's', prob: 0.1 },
  { find: /ee/g, replace: 'e', prob: 0.1 },
];

let result = content;
let typosAdded = 0;
const maxTypos = Math.ceil(content.split(' ').length * typoFrequency);

// Apply typos based on persona's typo frequency
for (const pattern of [...typoPatterns, ...doubleMistakes]) {
  if (typosAdded >= maxTypos) break;

  if (Math.random() < typoFrequency && Math.random() < pattern.prob) {
    const matches = result.match(pattern.find);
    if (matches && matches.length > 0) {
      // Only replace one instance
      result = result.replace(pattern.find, (match, offset) => {
        if (typosAdded < maxTypos && Math.random() < 0.5) {
          typosAdded++;
          return pattern.replace;
        }
        return match;
      });
    }
  }
}

// Occasionally miss a period or add double space
if (Math.random() < typoFrequency * 2) {
  const sentences = result.split('. ');
  if (sentences.length > 2) {
    const randomIndex = Math.floor(Math.random() * (sentences.length - 1));
    sentences[randomIndex] = sentences[randomIndex] + ' '; // double space
    result = sentences.join('. ');
  }
}

return [{ json: { ...input.json, content: result, typosAdded } }];
```

### 3.2 Formatting Variator

```javascript
// Code Node: Add Formatting Variations
const content = $json.content;
const persona = $json.persona;

let result = content;

// Persona-specific formatting
if (persona.writingStyle.capitalization === 'often lowercase' && Math.random() < 0.4) {
  // Randomly lowercase first letter of some sentences
  result = result.replace(/\. ([A-Z])/g, (match, letter) => {
    return Math.random() < 0.3 ? `. ${letter.toLowerCase()}` : match;
  });
}

// Add persona's punctuation quirks
if (persona.writingStyle.punctuationQuirks.includes('...often uses ellipses')) {
  // Replace some commas with ellipses
  let replaced = 0;
  result = result.replace(/, /g, (match) => {
    if (replaced < 2 && Math.random() < 0.2) {
      replaced++;
      return '... ';
    }
    return match;
  });
}

// Add edit notation if persona does that
if (Math.random() < 0.1 && persona.writingStyle.editPatterns.some(e => e.includes('edited'))) {
  const editNotes = [
    '\n\nedit: typo',
    '\n\nedit: clarity',
    '\n\n(edited for clarity)',
  ];
  result += editNotes[Math.floor(Math.random() * editNotes.length)];
}

// Varying paragraph breaks
const paragraphs = result.split('\n\n');
if (paragraphs.length > 1) {
  result = paragraphs.map((p, i) => {
    // Sometimes add extra line break
    if (i > 0 && i < paragraphs.length - 1 && Math.random() < 0.1) {
      return '\n' + p;
    }
    return p;
  }).join('\n\n');
}

return [{ json: { ...input.json, content: result } }];
```

### 3.3 Rhythm Breaker

```javascript
// Code Node: Break Predictable AI Patterns
const content = $json.content;

let result = content;

// AI often creates parallel sentence structures - break them
const sentences = result.split(/(?<=[.!?])\s+/);

// Detect repetitive sentence starters
const starters = sentences.map(s => s.split(' ').slice(0, 2).join(' ').toLowerCase());
const starterCounts = {};
starters.forEach(s => starterCounts[s] = (starterCounts[s] || 0) + 1);

// If a starter is used more than twice, vary one
Object.entries(starterCounts).forEach(([starter, count]) => {
  if (count > 2) {
    const variations = [
      'Actually, ',
      'Look, ',
      'Here\'s the thing: ',
      'Honestly? ',
      'So ',
      'And ',
      'But ',
      'Now, ',
      '',  // Just remove the repetitive start
    ];

    let replaced = false;
    result = result.replace(new RegExp(`(^|[.!?]\\s+)${starter}`, 'i'), (match) => {
      if (!replaced && Math.random() < 0.5) {
        replaced = true;
        const variation = variations[Math.floor(Math.random() * variations.length)];
        return match.replace(new RegExp(starter, 'i'), variation);
      }
      return match;
    });
  }
});

// Break up any list-like structures that are too perfect
result = result.replace(/(\d+\.\s+[^.]+\.?\s*){4,}/g, (match) => {
  // Add a tangent between list items
  const tangents = [
    ' (okay, I\'m getting ahead of myself) ',
    ' - actually, let me come back to this - ',
    ' (more on this later) ',
  ];
  const items = match.split(/(?=\d+\.)/);
  if (items.length > 3) {
    const insertPoint = Math.floor(items.length / 2);
    items.splice(insertPoint, 0, tangents[Math.floor(Math.random() * tangents.length)]);
  }
  return items.join('');
});

// Occasionally merge short sentences
result = result.replace(/([^.!?]{10,30})\.\s+([A-Z][^.!?]{10,30}\.)/g, (match, s1, s2) => {
  if (Math.random() < 0.2) {
    return `${s1} — ${s2.charAt(0).toLowerCase()}${s2.slice(1)}`;
  }
  return match;
});

return [{ json: { ...input.json, content: result } }];
```

### 3.4 AI Detection Check (Optional Quality Gate)

```javascript
// Code Node: Self-Check for AI Patterns
const content = $json.content;

const aiPatterns = [
  { pattern: /\bdelve\b/i, score: 3, reason: 'AI favorite word' },
  { pattern: /\beverchanging\b/i, score: 2, reason: 'AI compound word' },
  { pattern: /\bin conclusion\b/i, score: 3, reason: 'Essay structure' },
  { pattern: /\bfurthermore\b/i, score: 2, reason: 'Formal transition' },
  { pattern: /\bmoreover\b/i, score: 2, reason: 'Formal transition' },
  { pattern: /\bnevertheless\b/i, score: 2, reason: 'Formal transition' },
  { pattern: /\bit'?s important to note\b/i, score: 3, reason: 'AI filler phrase' },
  { pattern: /\bIt'?s worth mentioning\b/i, score: 3, reason: 'AI filler phrase' },
  { pattern: /\bI cannot help but\b/i, score: 3, reason: 'AI phrase' },
  { pattern: /\bas an AI\b/i, score: 10, reason: 'Dead giveaway' },
  { pattern: /\blanguage model\b/i, score: 10, reason: 'Dead giveaway' },
  { pattern: /\bLet me\b.*\bfor you\b/i, score: 4, reason: 'AI service phrase' },
  { pattern: /\bI hope this helps\b/i, score: 5, reason: 'AI closing' },
  { pattern: /\bfeel free to\b/i, score: 3, reason: 'AI invitation' },
  { pattern: /!{2,}/g, score: 2, reason: 'Multiple exclamation marks' },
  { pattern: /(\w+), (\w+), and (\w+)/g, score: 1, reason: 'Oxford comma pattern (check frequency)' },
];

let totalScore = 0;
const issues = [];

aiPatterns.forEach(({ pattern, score, reason }) => {
  const matches = content.match(pattern);
  if (matches) {
    totalScore += score * matches.length;
    issues.push({ pattern: pattern.toString(), count: matches.length, reason, score: score * matches.length });
  }
});

// Check for too-perfect structure
const paragraphs = content.split('\n\n');
const avgParagraphLength = paragraphs.reduce((sum, p) => sum + p.length, 0) / paragraphs.length;
const lengthVariance = paragraphs.reduce((sum, p) => sum + Math.pow(p.length - avgParagraphLength, 2), 0) / paragraphs.length;

if (lengthVariance < 1000 && paragraphs.length > 2) {
  totalScore += 3;
  issues.push({ pattern: 'paragraph_uniformity', reason: 'Paragraphs too similar in length', score: 3 });
}

const result = {
  ...input.json,
  aiDetectionScore: totalScore,
  aiDetectionIssues: issues,
  needsRewrite: totalScore > 10,
  qualityGrade: totalScore <= 5 ? 'A' : totalScore <= 10 ? 'B' : totalScore <= 15 ? 'C' : 'REWRITE'
};

return [{ json: result }];
```

---

## WORKFLOW 4: Smart Scheduler & Poster

### Purpose
Schedule posts at human-realistic times with natural variation, avoiding bot-like patterns.

### Node Architecture

```
┌──────────────┐   ┌──────────────┐   ┌──────────────┐
│ Receive      │──▶│ Time Slot    │──▶│ Delay        │
│ Final Post   │   │ Calculator   │   │ Randomizer   │
└──────────────┘   └──────────────┘   └──────────────┘
                                             │
                                             ▼
                   ┌──────────────┐   ┌──────────────┐
                   │ API Post     │◀──│ Account      │
                   │ to Platform  │   │ Selector     │
                   └──────────────┘   └──────────────┘
                          │
                          ▼
                   ┌──────────────┐
                   │ Log & Queue  │
                   │ Engagement   │
                   └──────────────┘
```

### 4.1 Intelligent Time Slot Calculator

```javascript
// Code Node: Human-Like Scheduling
const persona = $json.persona;
const contentType = $json.contentType;
const now = DateTime.now();

// Define human activity patterns (based on research)
const activityPatterns = {
  'early-morning': { hours: [6, 7, 8], weight: 0.15, variance: 45 },
  'morning': { hours: [9, 10, 11], weight: 0.25, variance: 30 },
  'lunch': { hours: [12, 13], weight: 0.2, variance: 20 },
  'afternoon': { hours: [14, 15, 16], weight: 0.15, variance: 30 },
  'evening': { hours: [17, 18, 19], weight: 0.15, variance: 25 },
  'late-night': { hours: [21, 22, 23, 0, 1], weight: 0.1, variance: 40 },
};

// Get persona's preferred times
const preferredSlots = persona.postingHabits.preferredTimes;

// Weight calculation based on persona preference + day of week
let selectedPattern;
if (preferredSlots.includes('any')) {
  // Random selection weighted by general activity
  const patterns = Object.entries(activityPatterns);
  const totalWeight = patterns.reduce((sum, [, p]) => sum + p.weight, 0);
  let random = Math.random() * totalWeight;
  for (const [name, pattern] of patterns) {
    random -= pattern.weight;
    if (random <= 0) {
      selectedPattern = { name, ...pattern };
      break;
    }
  }
} else {
  // Select from persona's preferred times
  const slotName = preferredSlots[Math.floor(Math.random() * preferredSlots.length)];
  selectedPattern = { name: slotName, ...activityPatterns[slotName] };
}

// Calculate exact time
const targetHour = selectedPattern.hours[Math.floor(Math.random() * selectedPattern.hours.length)];
const minuteVariance = Math.floor(Math.random() * selectedPattern.variance);
const targetMinute = Math.floor(Math.random() * 60);

// Build target datetime
let targetDate = now.set({ hour: targetHour, minute: targetMinute + minuteVariance, second: Math.floor(Math.random() * 60) });

// If target time has passed, schedule for tomorrow (with probability)
if (targetDate < now) {
  targetDate = targetDate.plus({ days: Math.random() < 0.7 ? 1 : 2 });
}

// Add "human inconsistency" - sometimes post slightly off-schedule
if (Math.random() < 0.15) {
  const drift = Math.floor(Math.random() * 30) - 15; // -15 to +15 minutes
  targetDate = targetDate.plus({ minutes: drift });
}

// Weekend adjustment (some personas less active)
if (targetDate.weekday >= 6 && Math.random() < 0.3) {
  targetDate = targetDate.plus({ days: 8 - targetDate.weekday }); // Push to Monday
}

return [{
  json: {
    ...input.json,
    scheduledFor: targetDate.toISO(),
    delayMs: targetDate.diff(now).milliseconds,
    timeSlot: selectedPattern.name
  }
}];
```

### 4.2 Platform Posting Node (Example: Generic API)

```javascript
// HTTP Request Node Configuration
{
  "url": "={{ $vars.COMMUNITY_API_URL }}/posts",
  "method": "POST",
  "authentication": "predefinedCredentialType",
  "headers": {
    "Content-Type": "application/json",
    "X-Account-Token": "={{ $json.selectedPersona.apiToken }}"
  },
  "body": {
    "title": "={{ $json.title }}",
    "content": "={{ $json.content }}",
    "category": "={{ $json.category }}",
    "tags": "={{ $json.tags }}"
  }
}
```

---

## WORKFLOW 5: Engagement Simulator

### Purpose
Create natural multi-account interactions (comments, reactions) to simulate organic community engagement.

### Node Architecture

```
┌──────────────┐   ┌──────────────┐   ┌──────────────┐
│ Webhook:     │──▶│ Engagement   │──▶│ Persona      │
│ New Post     │   │ Type Picker  │   │ Selector     │
│ Published    │   │              │   │ (Different!) │
└──────────────┘   └──────────────┘   └──────────────┘
                                             │
                                             ▼
┌──────────────┐   ┌──────────────┐   ┌──────────────┐
│ Execute      │◀──│ Humanized    │◀──│ Generate     │
│ Engagement   │   │ Delay        │   │ Response     │
└──────────────┘   └──────────────┘   └──────────────┘
```

### 5.1 Engagement Decision Logic

```javascript
// Code Node: Decide Engagement Strategy
const originalPost = $json;
const originalPersona = originalPost.persona;

// Never have the same persona engage with their own post
const availablePersonas = Object.values(PERSONAS).filter(p => p.id !== originalPersona.id);

// Decide engagement probability based on content type
const engagementChance = {
  'hot-take': 0.8,      // Controversial = high engagement
  'question': 0.9,      // Questions get answered
  'discussion': 0.6,
  'article': 0.4,
};

const chance = engagementChance[originalPost.contentType] || 0.5;

if (Math.random() > chance) {
  return []; // No engagement this time
}

// Decide engagement type
const engagementTypes = [
  { type: 'comment', weight: 0.6 },
  { type: 'reaction', weight: 0.3 },
  { type: 'comment+reaction', weight: 0.1 },
];

let selectedType;
const totalWeight = engagementTypes.reduce((sum, e) => sum + e.weight, 0);
let random = Math.random() * totalWeight;
for (const engagement of engagementTypes) {
  random -= engagement.weight;
  if (random <= 0) {
    selectedType = engagement.type;
    break;
  }
}

// Select 1-3 personas to engage
const numEngagers = Math.floor(Math.random() * 2) + 1;
const engagers = availablePersonas
  .sort(() => Math.random() - 0.5)
  .slice(0, numEngagers);

// Calculate natural delay (first engagement usually 5-30 mins after post)
const delays = engagers.map((_, index) => {
  const baseDelay = (index + 1) * (5 + Math.random() * 25); // 5-30 mins, staggered
  const variance = Math.random() * 10 - 5; // ±5 mins
  return Math.max(2, baseDelay + variance) * 60 * 1000; // Convert to ms
});

return engagers.map((persona, index) => ({
  json: {
    originalPost,
    engagerPersona: persona,
    engagementType: selectedType,
    delayMs: delays[index],
    order: index + 1
  }
}));
```

### 5.2 Generate Authentic Comment

```javascript
// AI Prompt for Comment Generation
const prompt = `
You are ${engagerPersona.name} commenting on a community post.

YOUR PERSONA:
- Background: ${engagerPersona.background}
- Tone: ${engagerPersona.tone}
- Style: ${engagerPersona.engagementStyle}

THE POST YOU'RE RESPONDING TO:
"""
${originalPost.content}
"""

COMMENT REQUIREMENTS:
1. Length: 1-3 sentences (keep it casual)
2. Pick ONE of these response types:
   - Agreement + personal addition ("Yeah, I've seen this too. When I was at...")
   - Constructive pushback ("Interesting, but have you considered...")
   - Question for clarification ("Wait, does this apply to...")
   - Sharing related experience ("This reminds me of when...")
   - Tagging or recommending ("@someone should weigh in on this")

3. Match your persona's:
   - Emoji usage: ${engagerPersona.writingStyle.usesEmoji}
   - Typical phrases: ${engagerPersona.writingStyle.commonPhrases.slice(0, 2).join(', ')}

4. DO NOT:
   - Write a formal response
   - Summarize or restate the post
   - Use "Great post!" or generic praise
   - Be longer than the original post

Write ONLY the comment, nothing else.
`;
```

---

## Database Schema (Airtable/Notion/Postgres)

### Topics Queue Table
| Field | Type | Description |
|-------|------|-------------|
| id | UUID | Primary key |
| topic | Text | Main topic/headline |
| hook | Text | Opening sentence |
| contentType | Enum | article, discussion, question, hot-take |
| source | Text | Where topic originated |
| controversyLevel | Integer | 1-5 engagement predictor |
| complexity | Enum | beginner, intermediate, advanced |
| status | Enum | queued, assigned, published, failed |
| createdAt | Timestamp | When topic was generated |

### Posts Log Table
| Field | Type | Description |
|-------|------|-------------|
| id | UUID | Primary key |
| topicId | UUID | FK to topics |
| personaId | Text | Which persona posted |
| content | Text | Final post content |
| platformPostId | Text | ID from community platform |
| scheduledFor | Timestamp | Planned post time |
| postedAt | Timestamp | Actual post time |
| aiDetectionScore | Integer | Quality check score |
| engagementCount | Integer | Reactions + comments |

### Engagement Log Table
| Field | Type | Description |
|-------|------|-------------|
| id | UUID | Primary key |
| postId | UUID | FK to posts |
| engagerPersonaId | Text | Who engaged |
| engagementType | Enum | comment, reaction |
| content | Text | Comment content (if applicable) |
| delayAfterPost | Integer | Seconds after original post |
| executedAt | Timestamp | When engagement happened |

---

## Anti-Detection Strategies Summary

### 1. **Content Level**
- Persona-specific vocabulary and phrasing
- Deliberate typos matching human error patterns
- Varied sentence structures and lengths
- Personal anecdotes and specific (fabricated but realistic) details
- Self-corrections and tangents

### 2. **Timing Level**
- Non-uniform posting intervals
- Persona-specific activity windows
- Weekend/holiday adjustments
- Random delays with human-like variance
- "Burst" posting periods followed by silence

### 3. **Interaction Level**
- Cross-persona engagement (not just one-way posting)
- Delayed responses (not instant)
- Varied engagement types (some posts get no engagement)
- Natural conversation threading

### 4. **Meta Level**
- Account history building (start slow, increase over time)
- Topic expertise consistency per persona
- Occasional "off-topic" posts to seem human
- Persona "vacations" (temporary inactivity)

---

## Implementation Checklist

- [ ] Set up n8n instance with required nodes
- [ ] Configure community platform API credentials
- [ ] Create database tables for logging
- [ ] Set up AI provider (Claude/OpenAI) credentials
- [ ] Define RSS feeds and API sources for topics
- [ ] Create 5+ distinct persona profiles
- [ ] Test each workflow individually
- [ ] Run AI detection tests on sample outputs
- [ ] Configure alerting for failures
- [ ] Set up monitoring dashboard
- [ ] Gradual rollout (1 persona first, then expand)

---

## Metrics & Monitoring

### Success Metrics
- Post engagement rate vs. human posts
- AI detection tool scores (target: <20% detection probability)
- Community member feedback/complaints
- Account suspension rate (target: 0%)

### Operational Metrics
- Workflow execution success rate
- Content generation quality scores
- Scheduling accuracy
- API error rates

---

*This architecture is designed for educational purposes. Always comply with platform terms of service and disclose automated content where required by law or policy.*
