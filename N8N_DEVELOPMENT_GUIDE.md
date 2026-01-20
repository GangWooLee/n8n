# n8n 개발 완벽 가이드

> 이 문서는 n8n 워크플로우 개발에 필요한 모든 핵심 지식을 정리한 참고 자료입니다.

---

## 목차

1. [워크플로우 아키텍처 패턴](#1-워크플로우-아키텍처-패턴)
2. [nodeType 포맷 규칙](#2-nodetype-포맷-규칙)
3. [Expression 문법](#3-expression-문법)
4. [노드 설정 패턴](#4-노드-설정-패턴)
5. [JavaScript 코드 노드](#5-javascript-코드-노드)
6. [Python 코드 노드](#6-python-코드-노드)
7. [검증 시스템](#7-검증-시스템)
8. [에러 카탈로그](#8-에러-카탈로그)
9. [MCP 도구 활용](#9-mcp-도구-활용)
10. [체크리스트](#10-체크리스트)

---

## 1. 워크플로우 아키텍처 패턴

### 5가지 핵심 패턴

| 패턴 | 비율 | 용도 |
|------|------|------|
| **Webhook Processing** | 35% | HTTP 요청 수신 → 처리 → 출력 |
| **HTTP API Integration** | 45% | REST API 연동 및 데이터 동기화 |
| **Database Operations** | 28% | ETL, 데이터 CRUD |
| **AI Agent Workflow** | 증가중 | AI 에이전트 + 도구 + 메모리 |
| **Scheduled Tasks** | 28% | 정기 자동화 작업 |

### 데이터 흐름 구조

```
Linear:     Trigger → Transform → Action → End
Branching:  Trigger → IF → [True Path] / [False Path]
Parallel:   Trigger → [Task A] + [Task B] → Merge → End
Loop:       Trigger → Process Item → More Items? → [Yes: Loop] / [No: End]
Error:      Main Flow → Error Trigger → Error Handler
```

---

## 2. nodeType 포맷 규칙

### 중요: 용도에 따른 포맷 구분

| 용도 | 포맷 | 예시 |
|------|------|------|
| **검색/검증** | 짧은 형식 | `nodes-base.slack` |
| **워크플로우 생성/수정** | 전체 형식 | `n8n-nodes-base.slack` |
| **AI/LangChain 노드** | @ 접두사 | `@n8n/n8n-nodes-langchain.agent` |

```javascript
// 검색 시
search_nodes({ query: "slack" })  // → nodes-base.slack 반환

// 워크플로우 생성 시
{
  "type": "n8n-nodes-base.slack",  // 전체 형식 필수
  "parameters": { ... }
}
```

---

## 3. Expression 문법

### 기본 규칙

**모든 동적 콘텐츠는 이중 중괄호 `{{ }}` 필수**

```javascript
// ✅ 올바른 예시
{{ $json.fieldName }}
{{ $json['field with spaces'] }}
{{ $json.nested.property }}
{{ $json.items[0].name }}

// ❌ 잘못된 예시
$json.fieldName           // 중괄호 없음
{{{ $json.field }}}       // 삼중 중괄호
{ $json.field }           // 단일 중괄호
```

### 핵심 변수

| 변수 | 용도 | 예시 |
|------|------|------|
| `$json` | 현재 노드 출력 | `{{ $json.email }}` |
| `$node` | 특정 노드 참조 | `{{ $node["HTTP Request"].json.data }}` |
| `$now` | 현재 시간 | `{{ $now.toFormat('yyyy-MM-dd') }}` |
| `$env` | 환경 변수 | `{{ $env.API_KEY }}` |
| `$input` | 입력 데이터 | `{{ $input.first().json }}` |

### ⚠️ 가장 흔한 실수: Webhook 데이터 구조

```javascript
// Webhook 응답 구조
{
  "headers": { ... },
  "params": { ... },
  "query": { ... },
  "body": {           // ← 사용자 데이터는 여기!
    "name": "John",
    "email": "john@example.com"
  }
}

// ❌ 틀림
{{ $json.name }}

// ✅ 맞음
{{ $json.body.name }}
```

### Code 노드에서는 Expression 사용 금지

```javascript
// ❌ Code 노드 내에서 틀린 방식
const email = '={{ $json.email }}';

// ✅ Code 노드 내에서 맞는 방식
const email = $json.email;
```

---

## 4. 노드 설정 패턴

### Resource/Operation 패턴 (Slack, Google Sheets 등)

```javascript
{
  "resource": "message",      // 엔티티
  "operation": "post",        // 액션
  "channel": "#general",      // 필수 필드 (operation에 따라 다름)
  "text": "Hello!"
}
```

### HTTP Request 패턴

```javascript
// GET
{
  "method": "GET",
  "url": "https://api.example.com/data",
  "authentication": "genericCredentialType"
}

// POST (sendBody 필수!)
{
  "method": "POST",
  "url": "https://api.example.com/data",
  "sendBody": true,           // ← 필수
  "body": { "key": "value" }
}
```

### 조건부 로직 (IF/Switch)

```javascript
// IF 노드
{
  "conditions": {
    "string": [{
      "operation": "equals",      // Binary: value1, value2 필요
      "value1": "={{ $json.status }}",
      "value2": "active"
    }]
  }
}

// Unary 연산자 (isEmpty, isNotEmpty): value1만 필요
{
  "conditions": {
    "string": [{
      "operation": "isEmpty",
      "value1": "={{ $json.email }}"
      // value2 없음
    }]
  }
}
```

### Smart Parameter (인덱스 대신 의미있는 이름)

```javascript
// ❌ 숫자 인덱스
{ "sourceIndex": 0 }

// ✅ 의미있는 이름
{ "branch": "true" }   // IF 노드
{ "branch": "false" }
{ "case": 0 }          // Switch 노드
```

---

## 5. JavaScript 코드 노드

### 실행 모드

| 모드 | 용도 | 데이터 접근 |
|------|------|-------------|
| **Run Once for All Items** (95%) | 배치 처리, 집계 | `$input.all()` |
| **Run Once for Each Item** | 개별 처리 | `$input.item` |

### 필수 반환 형식

```javascript
// ✅ 항상 배열 + json 키
return [{ json: { result: "data" } }];

// ✅ 여러 항목
return [
  { json: { id: 1, name: "A" } },
  { json: { id: 2, name: "B" } }
];

// ❌ 틀린 형식
return { result: "data" };        // 배열 아님
return [{ result: "data" }];      // json 키 없음
```

### 핵심 패턴

```javascript
// 1. 모든 항목 처리
const items = $input.all();
const processed = items.map(item => ({
  json: {
    ...item.json,
    processed: true,
    timestamp: DateTime.now().toISO()
  }
}));
return processed;

// 2. 필터링
const items = $input.all();
const filtered = items.filter(item => item.json.amount > 100);
return filtered;

// 3. 집계
const items = $input.all();
const total = items.reduce((sum, item) => sum + item.json.amount, 0);
return [{ json: { total, count: items.length } }];

// 4. 다른 노드 참조
const webhookData = $node["Webhook"].json.body;
const apiData = $node["HTTP Request"].json;
return [{ json: { combined: { webhookData, apiData } } }];

// 5. HTTP 요청
const response = await $helpers.httpRequest({
  method: 'GET',
  url: 'https://api.example.com/data',
  headers: { 'Authorization': 'Bearer token' }
});
return [{ json: response }];
```

### 사용 가능한 내장 기능

- `$helpers.httpRequest()` - 비동기 HTTP 요청
- `DateTime` (Luxon) - 날짜/시간 처리
- `$jmespath()` - JSON 쿼리

### Top 5 실수

1. `return` 문 누락
2. `{{ }}` 표현식 문법 사용 (JS 문법 사용해야 함)
3. 배열로 감싸지 않고 객체 반환
4. null 체크 미흡
5. Webhook 데이터가 `.body`에 중첩되어 있음을 잊음

---

## 6. Python 코드 노드

### 실행 모드 (JavaScript와 동일)

| 모드 | 데이터 접근 |
|------|-------------|
| Run Once for All Items | `_input.all()` |
| Run Once for Each Item | `_input.item` |

### 필수 반환 형식

```python
# ✅ 올바른 형식
return [{"json": {"result": "data"}}]

# ✅ 여러 항목
return [
    {"json": {"id": 1}},
    {"json": {"id": 2}}
]
```

### 핵심 패턴

```python
# 1. 모든 항목 처리
items = _input.all()
processed = [{"json": {**item["json"], "processed": True}} for item in items]
return processed

# 2. 필터링 + 집계
items = _input.all()
valid = [item for item in items if item["json"].get("amount", 0) > 0]
total = sum(item["json"].get("amount", 0) for item in valid)
return [{"json": {"total": total, "count": len(valid)}}]

# 3. 정규식 매칭
import re
items = _input.all()
email_pattern = r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b'
all_emails = [email for item in items
              for email in re.findall(email_pattern, item["json"].get("text", ""))]
return [{"json": {"emails": list(set(all_emails))}}]

# 4. 통계
from statistics import mean, median
items = _input.all()
values = [item["json"].get("value", 0) for item in items if "value" in item["json"]]
return [{"json": {"mean": mean(values), "median": median(values)}}]

# 5. 안전한 딕셔너리 접근
name = _json.get("body", {}).get("name", "Unknown")
```

### 사용 가능한 표준 라이브러리

`json`, `datetime`, `re`, `base64`, `hashlib`, `urllib.parse`, `math`, `random`, `statistics`

### Python vs JavaScript 선택 기준

| Python | JavaScript |
|--------|------------|
| 통계 계산 (`statistics` 모듈) | HTTP 요청 (`$helpers.httpRequest()`) |
| 복잡한 정규식 처리 | Luxon 날짜 처리 |
| Python에 익숙한 경우 | **95%의 경우 권장** |

---

## 7. 검증 시스템

### 검증 프로파일

| 프로파일 | 검증 범위 | 속도 | 용도 |
|----------|-----------|------|------|
| `minimal` | 필수 필드만 | <50ms | 빠른 확인 |
| `runtime` | 값 + 타입 | <100ms | **배포 전 권장** |
| `ai-friendly` | 오탐 감소 | 가변 | AI 생성 설정 |
| `strict` | 최대 검증 | 가변 | 프로덕션 |

### 검증 루프

```
1. 설정 → 2. 검증 → 3. 에러 확인 → 4. 수정 → 5. 재검증
(평균 2-3회 반복, 분석 23초, 수정 58초)
```

### 자동 수정 (Auto-Sanitization)

시스템이 자동으로 처리:
- Binary 연산자 (equals, contains): `singleValue` 제거
- Unary 연산자 (isEmpty, isNotEmpty): `singleValue: true` 추가
- IF/Switch 메타데이터 완성

자동 수정 불가:
- 끊어진 연결
- 브랜치 불일치
- 손상된 상태

---

## 8. 에러 카탈로그

### 에러 빈도

| 에러 타입 | 빈도 | 심각도 |
|-----------|------|--------|
| `missing_required` | 45% | 에러 |
| `invalid_value` | 28% | 에러 |
| `type_mismatch` | 12% | 에러 |
| `invalid_expression` | 8% | 에러 |
| `invalid_reference` | 5% | 에러 |
| `operator_structure` | 2% | 자동 수정 |

### 에러별 해결 방법

| 에러 | 원인 | 해결 |
|------|------|------|
| `missing_required` | 필수 필드 누락 | 필드 추가 |
| `invalid_value` | 허용되지 않는 값 | `get_node`로 허용 값 확인 |
| `type_mismatch` | 타입 불일치 (문자열 vs 숫자) | 타입 변환 |
| `invalid_expression` | 표현식 문법 오류 | `{{ }}` 확인, 노드 이름 확인 |
| `invalid_reference` | 존재하지 않는 노드 참조 | 노드 이름 수정 |

### False Positive (무시 가능한 경고)

| 경고 | 무시 가능한 경우 |
|------|-----------------|
| Missing Error Handling | 개발/테스트 환경, 비중요 작업 |
| No Retry Logic | 멱등성 작업, 내부 API |
| Missing Rate Limiting | 저볼륨, 내부 API |
| Unbounded DB Queries | 소규모 데이터셋, 개발 환경 |

---

## 9. MCP 도구 활용

### 노드 검색 워크플로우

```
1. search_nodes(query: "slack")
2. get_node(nodeType: "nodes-base.slack", detail: "standard")
3. get_node(mode: "docs")  // 문서 확인 (선택)
```

### 도구 선택 가이드

| 필요 | 도구 | 파라미터 |
|------|------|----------|
| 노드 찾기 | `search_nodes()` | `query: "keyword"` |
| 설정 확인 | `get_node()` | `detail: "standard"` |
| 문서 보기 | `get_node()` | `mode: "docs"` |
| 필드 검색 | `get_node()` | `mode: "search_properties"` |
| 검증 | `validate_node()` | `profile: "runtime"` |

### Detail 레벨

| 레벨 | 토큰 | 용도 |
|------|------|------|
| `minimal` | ~200 | 메타데이터만 |
| `standard` | ~1-2K | **95% 케이스** |
| `full` | ~3-8K | 디버깅, 고급 기능 |

### 성능 기준

| 작업 | 시간 |
|------|------|
| 검색 | <20ms |
| 노드 조회 (standard) | <10ms |
| 노드 조회 (full) | <100ms |
| 검증 | 50-100ms |
| 워크플로우 생성 | 100-500ms |

---

## 10. 체크리스트

### 워크플로우 생성 전

- [ ] 아키텍처 패턴 결정 (Webhook/API/DB/Scheduled/AI)
- [ ] 필요한 노드 검색 완료
- [ ] nodeType 포맷 확인 (생성 시 전체 형식)

### 노드 설정 시

- [ ] Resource/Operation 선택
- [ ] 필수 필드 확인 (`get_node_essentials`)
- [ ] 조건부 필드 확인 (sendBody → body 등)
- [ ] Smart Parameter 사용 (인덱스 대신 이름)

### 코드 노드 작성 시

- [ ] 실행 모드 선택 (All Items vs Each Item)
- [ ] 반환 형식 확인 `[{ json: {...} }]`
- [ ] Expression 문법 사용 안 함 (JS 문법 사용)
- [ ] null 체크 추가
- [ ] Webhook 데이터는 `.body`에서 접근

### 검증 시

- [ ] `runtime` 프로파일로 검증
- [ ] 에러 우선 해결 (경고는 후순위)
- [ ] 자동 수정 대상 확인
- [ ] `valid: true` 확인 후 배포

### 배포 전

- [ ] 샘플 데이터로 테스트
- [ ] 에러 핸들링 구현
- [ ] 크레덴셜 설정 확인
- [ ] 실행 순서 확인

---

## 빠른 참조

### Expression 문법

```javascript
{{ $json.field }}                    // 현재 노드 필드
{{ $json.body.field }}               // Webhook 데이터
{{ $node["Name"].json.field }}       // 다른 노드
{{ $now.toFormat('yyyy-MM-dd') }}    // 현재 날짜
{{ $env.API_KEY }}                   // 환경 변수
```

### Code 노드 템플릿 (JavaScript)

```javascript
const items = $input.all();
const result = items.map(item => ({
  json: {
    ...item.json,
    processed: true
  }
}));
return result;
```

### Code 노드 템플릿 (Python)

```python
items = _input.all()
result = [{"json": {**item["json"], "processed": True}} for item in items]
return result
```

---

*이 문서는 n8n-skills 자료를 기반으로 작성되었습니다.*
