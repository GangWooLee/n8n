이어서 # API Design Document

## 문서 정보
- **프로젝트**: Startup Community Platform
- **API 스타일**: RESTful + Hotwire (Turbo)
- **버전**: v1 (MVP)
- **응답 형식**: HTML (Turbo) / JSON (API)
- **업데이트**: 2025-12-31

---

## 1. 아키텍처 개요

### 1.1 Hotwire 우선 접근
이 프로젝트는 **Hotwire (Turbo + Stimulus)**를 사용한 **Modern Rails** 애플리케이션입니다.
- **기본 응답**: HTML (Turbo Drive, Turbo Frames, Turbo Streams)
- **API 응답**: JSON (필요 시)

### 1.2 라우팅 전략
- **RESTful 리소스 기반** 라우팅
- **중첩 라우팅** 최소화 (최대 1레벨)
- **커스텀 액션** 최소화

---

## 2. 라우팅 설계

### 2.1 인증 (Authentication)

```ruby
# config/routes.rb

# 회원가입/로그인
get    'signup',  to: 'users#new'
post   'signup',  to: 'users#create'
get    'login',   to: 'sessions#new'
post   'login',   to: 'sessions#create'
delete 'logout',  to: 'sessions#destroy'
```

**엔드포인트**:
- `GET /signup` - 회원가입 폼
- `POST /signup` - 회원가입 처리
- `GET /login` - 로그인 폼
- `POST /login` - 로그인 처리 (Remember Me 지원)
- `DELETE /logout` - 로그아웃

**Remember Me (로그인 상태 유지)**:
- `POST /login` 시 `remember_me=1` 파라미터 전달
- 영구 쿠키 저장: `user_id`, `remember_token` (20년 유효)
- BCrypt 기반 `remember_digest` 검증
- 로그아웃 시 `remember_digest` 삭제 및 쿠키 제거

---

### 2.2 OAuth 소셜 로그인

```ruby
# OmniAuth 콜백 라우트 (자동 생성)
get '/auth/:provider/callback', to: 'omniauth_callbacks#create'
get '/auth/failure', to: 'omniauth_callbacks#failure'
```

**엔드포인트**:
- `GET /auth/google_oauth2` - Google 로그인 리다이렉트
- `GET /auth/github` - GitHub 로그인 리다이렉트
- `GET /auth/:provider/callback` - OAuth 콜백 처리
  - 동일 이메일 계정 자동 통합 (oauth_identities 테이블)
  - 신규 사용자 자동 회원가입

**OAuth 제공자**:
| 제공자 | provider 값 | 설명 |
|--------|------------|------|
| Google | google_oauth2 | Google 계정 로그인 |
| GitHub | github | GitHub 계정 로그인 |

---

### 2.3 커뮤니티 게시판 (Posts)

```ruby
resources :posts do
  member do
    post :increment_view  # 조회수 증가
  end

  resources :comments, only: [:create, :destroy], shallow: true
  resources :likes, only: [:create, :destroy], shallow: true
end
```

**엔드포인트**:

#### Posts
- `GET /posts` - 게시글 목록
- `GET /posts/:id` - 게시글 상세
- `GET /posts/new` - 게시글 작성 폼
- `POST /posts` - 게시글 생성
- `GET /posts/:id/edit` - 게시글 수정 폼
- `PATCH /posts/:id` - 게시글 수정
- `DELETE /posts/:id` - 게시글 삭제
- `POST /posts/:id/increment_view` - 조회수 증가

#### Comments (nested)
- `POST /posts/:post_id/comments` - 댓글 작성
- `DELETE /comments/:id` - 댓글 삭제

#### Likes (nested)
- `POST /posts/:post_id/likes` - 좋아요 추가
- `DELETE /likes/:id` - 좋아요 취소

---

### 2.3 프로필 (Profiles)

```ruby
resources :users, only: [:show, :edit, :update], path: 'profiles', as: 'profiles' do
  member do
    get :posts           # 사용자의 게시글
    get :job_posts       # 사용자의 구인 글
    get :talent_listings # 사용자의 구직 글
  end
end
```

**엔드포인트**:
- `GET /profiles/:id` - 프로필 페이지 (기본: Posts 탭)
- `GET /profiles/:id/posts` - Posts 탭
- `GET /profiles/:id/job_posts` - Job Posts 탭
- `GET /profiles/:id/talent_listings` - Talent Listings 탭
- `GET /profiles/:id/edit` - 프로필 수정 폼
- `PATCH /profiles/:id` - 프로필 수정

---

### 2.4 외주 - 구인 (Job Posts)

```ruby
resources :job_posts do
  member do
    post :increment_view
  end
  resources :bookmarks, only: [:create, :destroy], shallow: true
end
```

**엔드포인트**:
- `GET /job_posts` - 구인 공고 목록
- `GET /job_posts/:id` - 구인 공고 상세
- `GET /job_posts/new` - 구인 공고 작성 폼
- `POST /job_posts` - 구인 공고 생성
- `GET /job_posts/:id/edit` - 구인 공고 수정 폼
- `PATCH /job_posts/:id` - 구인 공고 수정
- `DELETE /job_posts/:id` - 구인 공고 삭제
- `POST /job_posts/:id/increment_view` - 조회수 증가

---

### 2.5 외주 - 구직 (Talent Listings)

```ruby
resources :talent_listings do
  member do
    post :increment_view
  end
  resources :bookmarks, only: [:create, :destroy], shallow: true
end
```

**엔드포인트**:
- `GET /talent_listings` - 구직 정보 목록
- `GET /talent_listings/:id` - 구직 정보 상세
- `GET /talent_listings/new` - 구직 정보 작성 폼
- `POST /talent_listings` - 구직 정보 생성
- `GET /talent_listings/:id/edit` - 구직 정보 수정 폼
- `PATCH /talent_listings/:id` - 구직 정보 수정
- `DELETE /talent_listings/:id` - 구직 정보 삭제
- `POST /talent_listings/:id/increment_view` - 조회수 증가

---

### 2.6 마이페이지 (My Page)

```ruby
namespace :my do
  resource :profile, only: [:edit, :update]
  resources :bookmarks, only: [:index, :destroy]
  resources :posts, only: [:index]
  resources :job_posts, only: [:index]
  resources :talent_listings, only: [:index]
end
```

**엔드포인트**:
- `GET /my/profile/edit` - 내 프로필 수정
- `PATCH /my/profile` - 내 프로필 업데이트
- `GET /my/bookmarks` - 내 스크랩 목록
- `DELETE /my/bookmarks/:id` - 스크랩 삭제
- `GET /my/posts` - 내가 쓴 게시글
- `GET /my/job_posts` - 내가 올린 구인 글
- `GET /my/talent_listings` - 내가 올린 구직 글

---

### 2.7 AI 온보딩

```ruby
# 랜딩 페이지 (루트)
root 'onboarding#landing'

# AI 분석 플로우
get 'ai/input', to: 'onboarding#ai_input'        # 아이디어 입력 (로그인 필수)
post 'ai/questions', to: 'onboarding#ai_questions'  # 추가 질문 생성 (JSON)
get 'ai/result', to: 'onboarding#ai_result'      # 분석 결과 (5개 에이전트)
get 'ai/expert/:id', to: 'onboarding#expert_profile'  # 전문가 프로필 (Turbo Stream)

# 커뮤니티 (서브라우트)
get 'community', to: 'posts#index'
```

**엔드포인트**:

#### 온보딩 플로우
- `GET /` - 랜딩 페이지 (AI 분석 소개)
- `GET /ai/input` - 아이디어 입력 폼 (로그인 필수)
- `POST /ai/questions` - 추가 질문 생성 (JSON 응답)
  - 요청: `{ idea: "아이디어 텍스트" }`
  - 응답: `{ questions: [{ id: "target", question: "...", placeholder: "..." }] }`
- `GET /ai/result` - 분석 결과 페이지
  - 5개 전문 에이전트 순차 실행
  - 파라미터: `idea`, `answers` (JSON)
- `GET /ai/expert/:id` - 전문가 프로필 오버레이 (Turbo Stream)

---

### 2.8 Admin 패널

```ruby
namespace :admin do
  root 'dashboard#index'
  resources :users, only: [:index, :show, :edit, :update, :destroy] do
    member do
      patch :toggle_admin
    end
  end
  resources :chat_rooms, only: [:index, :show, :destroy]
end
```

**엔드포인트**:
- `GET /admin` - 관리자 대시보드
- `GET /admin/users` - 사용자 목록
- `PATCH /admin/users/:id/toggle_admin` - 관리자 권한 토글
- `GET /admin/chat_rooms` - 채팅방 목록
- `DELETE /admin/chat_rooms/:id` - 채팅방 삭제

---

### 2.9 채팅 (Chat)

```ruby
resources :chat_rooms, only: [:index, :show, :create] do
  resources :messages, only: [:create]
  member do
    post :mark_as_read
  end
end
```

**엔드포인트**:
- `GET /chat_rooms` - 채팅방 목록 (최근 순)
- `GET /chat_rooms/:id` - 채팅방 상세 (메시지 목록)
- `POST /chat_rooms` - 채팅방 생성 (또는 기존 채팅방으로 리다이렉트)
- `POST /chat_rooms/:id/messages` - 메시지 전송 (Turbo Stream)
- `POST /chat_rooms/:id/mark_as_read` - 읽음 표시

**채팅 플로우**:
1. 프로필 페이지에서 "메시지 보내기" 클릭
2. `POST /chat_rooms` (receiver_id 전달)
3. 기존 채팅방 있으면 리다이렉트, 없으면 생성
4. 채팅방 페이지에서 실시간 메시지 (Solid Cable, Turbo Streams)

---

### 2.10 검색 (Search)

```ruby
get 'search', to: 'search#index'
```

**엔드포인트**:
- `GET /search` - 검색 결과 페이지
- `GET /search?q=검색어` - 검색어로 검색
- `GET /search?q=검색어&tab=posts` - 게시글 탭
- `GET /search?q=검색어&tab=users` - 사용자 탭
- `GET /search?q=검색어&tab=outsourcing` - 외주 탭

**파라미터**:
- `q`: 검색어
- `tab`: 탭 필터 (posts, users, outsourcing)

**Stimulus 연동**:
- `live_search_controller.js` - 실시간 검색
- 검색 결과 클릭: `onmousedown` 사용 (blur 이벤트 충돌 방지)

---

### 2.11 알림 (Notifications)

```ruby
resources :notifications, only: [:index] do
  collection do
    post :mark_all_as_read
  end
  member do
    post :mark_as_read
  end
end
```

**엔드포인트**:
- `GET /notifications` - 알림 목록
- `POST /notifications/:id/mark_as_read` - 개별 알림 읽음 처리
- `POST /notifications/mark_all_as_read` - 전체 알림 읽음 처리

**알림 유형**:
| action | 설명 |
|--------|------|
| liked | 게시글/댓글 좋아요 |
| commented | 게시글에 댓글 |
| messaged | 새 채팅 메시지 |

---

### 2.12 회원 탈퇴 (User Deletion)

```ruby
# 사용자 탈퇴
resource :withdrawal, only: [:new, :create], controller: 'user_deletions'

# 관리자 탈퇴 기록 조회
namespace :admin do
  resources :user_deletions, only: [:index, :show] do
    member do
      post :reveal_personal_info  # 원본 정보 조회 (로그 기록)
    end
  end
end
```

**사용자 엔드포인트**:
- `GET /withdrawal/new` - 탈퇴 폼 (사유 선택)
- `POST /withdrawal` - 탈퇴 처리

**관리자 엔드포인트**:
- `GET /admin/user_deletions` - 탈퇴 기록 목록
- `GET /admin/user_deletions/:id` - 탈퇴 기록 상세
- `POST /admin/user_deletions/:id/reveal_personal_info` - 암호화된 원본 정보 복호화
  - 필수 파라미터: `reason` (열람 사유)
  - 자동 로그 기록: `AdminViewLog`

**탈퇴 프로세스**:
1. `POST /withdrawal` - 탈퇴 요청
2. 즉시 익명화 (이름, 이메일 → "탈퇴한 사용자")
3. 원본 정보 AES-256-GCM 암호화 보관
4. 5년 후 자동 파기 (`DestroyExpiredDeletionsJob`)

---

### 2.13 기타 Static 페이지

```ruby
# Static pages (선택)
get 'about', to: 'pages#about'
get 'terms', to: 'pages#terms'
get 'privacy', to: 'pages#privacy'
get 'settings', to: 'settings#show'  # 설정 페이지 (탈퇴 버튼)
```

---

## 3. 컨트롤러 설계

### 3.1 PostsController

```ruby
class PostsController < ApplicationController
  before_action :require_login, except: [:index, :show]
  before_action :set_post, only: [:show, :edit, :update, :destroy, :increment_view]
  before_action :authorize_user, only: [:edit, :update, :destroy]

  def index
    @pagy, @posts = pagy(Post.published.includes(:user).recent, items: 20)
  end

  def show
    @post
    @comments = @post.comments.includes(:user).recent
  end

  def new
    @post = Post.new
  end

  def create
    @post = current_user.posts.build(post_params)
    if @post.save
      redirect_to @post, notice: '게시글이 작성되었습니다.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @post
  end

  def update
    if @post.update(post_params)
      redirect_to @post, notice: '게시글이 수정되었습니다.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @post.destroy
    redirect_to posts_path, notice: '게시글이 삭제되었습니다.'
  end

  def increment_view
    @post.increment!(:views_count)
    head :ok
  end

  private

  def set_post
    @post = Post.find(params[:id])
  end

  def post_params
    params.require(:post).permit(:title, :content, :status)
  end

  def authorize_user
    redirect_to posts_path, alert: '권한이 없습니다.' unless @post.user == current_user
  end
end
```

---

### 3.2 CommentsController

```ruby
class CommentsController < ApplicationController
  before_action :require_login

  def create
    @post = Post.find(params[:post_id])
    @comment = @post.comments.build(comment_params.merge(user: current_user))

    if @comment.save
      # Turbo Stream 응답
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to @post }
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    @comment = Comment.find(params[:id])
    if @comment.user == current_user
      @comment.destroy
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to @comment.post }
      end
    end
  end

  private

  def comment_params
    params.require(:comment).permit(:content)
  end
end
```

---

### 3.3 LikesController

```ruby
class LikesController < ApplicationController
  before_action :require_login

  def create
    @post = Post.find(params[:post_id])
    @like = @post.likes.build(user: current_user)

    if @like.save
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to @post }
      end
    end
  end

  def destroy
    @like = Like.find(params[:id])
    if @like.user == current_user
      @like.destroy
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to @like.likeable }
      end
    end
  end
end
```

---

### 3.4 ProfilesController (UsersController)

```ruby
class ProfilesController < ApplicationController
  before_action :set_user

  def show
    @posts = @user.posts.published.recent.limit(10)
    @job_posts = @user.job_posts.open_positions.recent.limit(5)
    @talent_listings = @user.talent_listings.available.recent.limit(5)
  end

  def posts
    @pagy, @posts = pagy(@user.posts.published.recent)
    render :show
  end

  def job_posts
    @pagy, @job_posts = pagy(@user.job_posts.recent)
    render :show
  end

  def talent_listings
    @pagy, @talent_listings = pagy(@user.talent_listings.recent)
    render :show
  end

  def edit
    authorize_user
    @user
  end

  def update
    authorize_user
    if @user.update(user_params)
      redirect_to profile_path(@user), notice: '프로필이 업데이트되었습니다.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def user_params
    params.require(:user).permit(:name, :role_title, :bio, :avatar_url)
  end

  def authorize_user
    redirect_to root_path, alert: '권한이 없습니다.' unless @user == current_user
  end
end
```

---

### 3.5 JobPostsController & TalentListingsController

구조는 PostsController와 유사하며, 다음 차이점만 있습니다:
- 카테고리 필터링 (`params[:category]`)
- 프로젝트 타입 필터링 (`params[:project_type]`)
- 상태 필터링 (`params[:status]`)

```ruby
class JobPostsController < ApplicationController
  before_action :require_login, except: [:index, :show]

  def index
    @job_posts = JobPost.open_positions.includes(:user)
    @job_posts = @job_posts.where(category: params[:category]) if params[:category].present?
    @job_posts = @job_posts.where(project_type: params[:project_type]) if params[:project_type].present?

    @pagy, @job_posts = pagy(@job_posts.recent, items: 20)
  end

  # 나머지는 PostsController와 유사
end
```

---

## 4. 쿼리 파라미터

### 4.1 Posts Index
```
GET /posts?page=1&sort=recent
GET /posts?page=1&sort=popular
```

**파라미터**:
- `page`: 페이지 번호 (default: 1)
- `sort`: 정렬 (recent|popular) (default: recent)

---

### 4.2 Job Posts / Talent Listings Index
```
GET /job_posts?category=development&project_type=short_term&page=1
GET /talent_listings?category=design&status=available
```

**파라미터**:
- `category`: development|design|pm|marketing
- `project_type`: short_term|long_term|one_time
- `status`: (JobPost) open|closed|filled / (TalentListing) available|unavailable
- `page`: 페이지 번호

---

### 4.3 Profile Tabs
```
GET /profiles/:id/posts?page=1
GET /profiles/:id/job_posts?page=1
GET /profiles/:id/talent_listings?page=1
```

---

## 5. Turbo Streams (실시간 업데이트)

### 5.1 댓글 추가 (Turbo Stream)

**app/views/comments/create.turbo_stream.erb**:
```erb
<%= turbo_stream.append "comments" do %>
  <%= render @comment %>
<% end %>

<%= turbo_stream.update "comment-form" do %>
  <%= render "comments/form", post: @post, comment: Comment.new %>
<% end %>
```

### 5.2 좋아요 토글 (Turbo Stream)

**app/views/likes/create.turbo_stream.erb**:
```erb
<%= turbo_stream.replace "like-button-#{@post.id}" do %>
  <%= render "posts/like_button", post: @post %>
<% end %>

<%= turbo_stream.update "likes-count-#{@post.id}" do %>
  <%= @post.likes_count %>
<% end %>
```

---

## 6. JSON API (선택적)

필요 시 JSON API를 추가할 수 있습니다.

### 6.1 API 네임스페이스

```ruby
namespace :api do
  namespace :v1 do
    resources :posts, only: [:index, :show, :create, :update, :destroy]
    resources :job_posts, only: [:index, :show]
    resources :talent_listings, only: [:index, :show]
  end
end
```

### 6.2 JSON 응답 형식

```json
{
  "status": "success",
  "data": {
    "id": 1,
    "title": "게시글 제목",
    "content": "게시글 내용",
    "user": {
      "id": 1,
      "name": "사용자",
      "role_title": "Developer"
    },
    "created_at": "2025-11-26T10:00:00Z"
  }
}
```

### 6.3 에러 응답

```json
{
  "status": "error",
  "message": "Validation failed",
  "errors": {
    "title": ["can't be blank"],
    "content": ["can't be blank"]
  }
}
```

---

## 7. 보안

### 7.1 Strong Parameters

모든 컨트롤러에서 Strong Parameters 사용:
```ruby
def post_params
  params.require(:post).permit(:title, :content, :status)
end
```

### 7.2 인증 헬퍼

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  helper_method :current_user, :logged_in?

  private

  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end

  def logged_in?
    !!current_user
  end

  def require_login
    unless logged_in?
      redirect_to login_path, alert: '로그인이 필요합니다.'
    end
  end
end
```

### 7.3 CSRF 보호

Rails 기본 CSRF 보호 활성화 (자동):
```ruby
protect_from_forgery with: :exception
```

---

## 8. 페이지네이션

### 8.1 Pagy 사용 (권장)

```ruby
# Gemfile
gem 'pagy'

# app/controllers/application_controller.rb
include Pagy::Backend

# app/helpers/application_helper.rb
include Pagy::Frontend

# Controller
@pagy, @posts = pagy(Post.all, items: 20)

# View
<%== pagy_nav(@pagy) %>
```

---

## 9. 라우팅 요약

```ruby
# config/routes.rb
Rails.application.routes.draw do
  root 'posts#index'

  # Auth
  get    'signup',  to: 'users#new'
  post   'signup',  to: 'users#create'
  get    'login',   to: 'sessions#new'
  post   'login',   to: 'sessions#create'
  delete 'logout',  to: 'sessions#destroy'

  # Posts (Community)
  resources :posts do
    post :increment_view, on: :member
    resources :comments, only: [:create, :destroy], shallow: true
    resources :likes, only: [:create, :destroy], shallow: true
  end

  # Profiles
  resources :users, only: [:show, :edit, :update], path: 'profiles', as: 'profiles' do
    member do
      get :posts
      get :job_posts
      get :talent_listings
    end
  end

  # Job Posts
  resources :job_posts do
    post :increment_view, on: :member
  end

  # Talent Listings
  resources :talent_listings do
    post :increment_view, on: :member
  end

  # Bookmarks (polymorphic)
  resources :bookmarks, only: [:create, :destroy]

  # My Page
  namespace :my do
    resource :profile, only: [:edit, :update]
    resources :bookmarks, only: [:index, :destroy]
    resources :posts, only: [:index]
    resources :job_posts, only: [:index]
    resources :talent_listings, only: [:index]
  end
end
```

---

## 10. 테스트 예시

### 10.1 Controller Test

```ruby
# test/controllers/posts_controller_test.rb
require "test_helper"

class PostsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @post = posts(:one)
  end

  test "should get index" do
    get posts_url
    assert_response :success
  end

  test "should create post when logged in" do
    log_in_as(@user)

    assert_difference('Post.count') do
      post posts_url, params: { post: { title: "Test", content: "Content" } }
    end

    assert_redirected_to post_path(Post.last)
  end

  test "should not create post when not logged in" do
    assert_no_difference('Post.count') do
      post posts_url, params: { post: { title: "Test", content: "Content" } }
    end

    assert_redirected_to login_path
  end
end
```

---

## 변경 이력

| 날짜 | 변경사항 | 작성자 |
|------|----------|--------|
| 2025-12-31 | OAuth, Remember Me, 채팅, 검색, 알림, 회원 탈퇴 엔드포인트 추가 | Claude |
| 2025-12-27 | AI 온보딩, Admin 패널 라우트 추가 | Claude |
| 2025-11-26 | One-pager 기반 API 설계 (Hotwire 중심) | Claude |
