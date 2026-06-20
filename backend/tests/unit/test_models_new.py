"""
Model layer — comprehensive tests for forum_post, forum_question, community,
article_model, and partial db.py coverage.
All MongoDB calls are mocked via monkeypatch.
"""
import pytest
from unittest.mock import MagicMock, patch
from bson import ObjectId
from datetime import datetime, timezone


# ══════════════════════════════════════════════════════════════════════════════
# forum_post model
# ══════════════════════════════════════════════════════════════════════════════

def _mock_posts_col(monkeypatch, find_one_return=None, insert_one_return=None,
                    update_one_return=None, find_return=None):
    mock = MagicMock()
    # Always set find_one so None is properly falsy (not a MagicMock)
    mock.return_value.find_one.return_value = find_one_return
    if insert_one_return:
        mock.return_value.insert_one.return_value = MagicMock(inserted_id=insert_one_return)
    if update_one_return is not None:
        mock.return_value.update_one.return_value = update_one_return
    if find_return is not None:
        chain = MagicMock()
        chain.sort.return_value = chain
        chain.skip.return_value = chain
        chain.limit.return_value = find_return
        mock.return_value.find.return_value = chain
    return mock


def test_create_post(monkeypatch):
    import app.models.forum_post as pm
    post_id = ObjectId()
    mock = MagicMock()
    mock.return_value.insert_one.return_value = MagicMock(inserted_id=post_id)
    monkeypatch.setattr("app.models.forum_post.forum_posts_col", mock)

    result = pm.create_post(
        author_id=str(ObjectId()),
        body="Test post",
        content_type="post",
        crop_tags=["tomato"],
        disease_tags=["blight"],
    )
    assert result["body"] == "Test post"
    assert result["_id"] == post_id


def test_create_post_invalid_content_type(monkeypatch):
    import app.models.forum_post as pm
    mock = MagicMock()
    mock.return_value.insert_one.return_value = MagicMock(inserted_id=ObjectId())
    monkeypatch.setattr("app.models.forum_post.forum_posts_col", mock)
    result = pm.create_post(str(ObjectId()), "body", content_type="invalid_type")
    assert result["content_type"] == "post"  # falls back to 'post'


def test_toggle_like_unlike(monkeypatch):
    import app.models.forum_post as pm
    user_id = str(ObjectId())
    post_id = ObjectId()
    existing_post = {"_id": post_id, "likes": [user_id], "likes_count": 1}

    mock = _mock_posts_col(monkeypatch, find_one_return=existing_post)
    monkeypatch.setattr("app.models.forum_post.forum_posts_col", mock)

    result = pm.toggle_like(str(post_id), user_id)
    assert result["liked"] is False
    assert result["likes_count"] == 0


def test_toggle_like_add(monkeypatch):
    import app.models.forum_post as pm
    user_id = str(ObjectId())
    post_id = ObjectId()
    existing_post = {"_id": post_id, "likes": [], "likes_count": 0}

    mock = _mock_posts_col(monkeypatch, find_one_return=existing_post)
    monkeypatch.setattr("app.models.forum_post.forum_posts_col", mock)

    result = pm.toggle_like(str(post_id), user_id)
    assert result["liked"] is True
    assert result["likes_count"] == 1


def test_toggle_like_not_found(monkeypatch):
    import app.models.forum_post as pm
    mock = _mock_posts_col(monkeypatch, find_one_return=None)
    monkeypatch.setattr("app.models.forum_post.forum_posts_col", mock)
    result = pm.toggle_like(str(ObjectId()), "user123")
    assert result is None


def test_add_comment(monkeypatch):
    import app.models.forum_post as pm
    post_id = str(ObjectId())
    author_id = str(ObjectId())

    mock_comments = MagicMock()
    mock_comments.return_value.insert_one.return_value = MagicMock(inserted_id=ObjectId())
    mock_posts = MagicMock()
    mock_posts.return_value.update_one.return_value = None

    monkeypatch.setattr("app.models.forum_post.forum_comments_col", mock_comments)
    monkeypatch.setattr("app.models.forum_post.forum_posts_col", mock_posts)

    result = pm.add_comment(post_id, author_id, "Great post!")
    assert result["body"] == "Great post!"


def test_get_comments(monkeypatch):
    import app.models.forum_post as pm
    post_id = str(ObjectId())
    comment = {"_id": ObjectId(), "body": "Nice", "created_at": datetime.now(timezone.utc)}

    mock_comments = MagicMock()
    chain = MagicMock()
    chain.sort.return_value = chain
    chain.skip.return_value = chain
    chain.limit.return_value = [comment]
    mock_comments.return_value.find.return_value = chain
    monkeypatch.setattr("app.models.forum_post.forum_comments_col", mock_comments)

    result = pm.get_comments(post_id, page=1, per_page=10)
    assert len(result) == 1


def test_get_posts_by_tags(monkeypatch):
    import app.models.forum_post as pm
    post = {"_id": ObjectId(), "body": "Tomato tips", "created_at": datetime.now(timezone.utc)}

    mock = MagicMock()
    chain = MagicMock()
    chain.sort.return_value = chain
    chain.skip.return_value = chain
    chain.limit.return_value = [post]
    mock.return_value.find.return_value = chain
    monkeypatch.setattr("app.models.forum_post.forum_posts_col", mock)

    result = pm.get_posts_by_tags(crop_tags=["tomato"], page=1, per_page=10)
    assert len(result) == 1


def test_get_posts_by_tags_no_filters(monkeypatch):
    import app.models.forum_post as pm
    mock = MagicMock()
    chain = MagicMock()
    chain.sort.return_value = chain
    chain.skip.return_value = chain
    chain.limit.return_value = []
    mock.return_value.find.return_value = chain
    monkeypatch.setattr("app.models.forum_post.forum_posts_col", mock)
    result = pm.get_posts_by_tags()
    assert result == []


def test_get_recent_posts(monkeypatch):
    import app.models.forum_post as pm
    mock = MagicMock()
    chain = MagicMock()
    chain.sort.return_value = chain
    chain.skip.return_value = chain
    chain.limit.return_value = []
    mock.return_value.find.return_value = chain
    monkeypatch.setattr("app.models.forum_post.forum_posts_col", mock)
    result = pm.get_recent_posts()
    assert result == []


def test_get_post_by_id(monkeypatch):
    import app.models.forum_post as pm
    post_id = ObjectId()
    post = {"_id": post_id, "body": "Hello"}
    mock = MagicMock()
    mock.return_value.find_one.return_value = post
    monkeypatch.setattr("app.models.forum_post.forum_posts_col", mock)
    result = pm.get_post_by_id(str(post_id))
    assert result["body"] == "Hello"


def test_serialize_post(monkeypatch):
    import app.models.forum_post as pm
    monkeypatch.setattr("app.models.forum_post.users_col", lambda: MagicMock(
        find_one=lambda q: {"name": "Ali", "photo_url": ""}
    ))
    post = {
        "_id": ObjectId(), "author_id": ObjectId(), "body": "Test",
        "content_type": "post", "media_url": "", "tags": {},
        "likes": [], "likes_count": 0, "comments_count": 0,
        "created_at": datetime.now(timezone.utc),
    }
    result = pm.serialize_post(post, current_user_id="some_user")
    assert result["body"] == "Test"
    assert result["liked_by_me"] is False


def test_serialize_post_none():
    import app.models.forum_post as pm
    assert pm.serialize_post(None) is None


def test_serialize_comment(monkeypatch):
    import app.models.forum_post as pm
    monkeypatch.setattr("app.models.forum_post.users_col", lambda: MagicMock(
        find_one=lambda q: None
    ))
    comment = {
        "_id": ObjectId(), "post_id": ObjectId(), "author_id": ObjectId(),
        "body": "Nice post", "created_at": datetime.now(timezone.utc),
    }
    result = pm.serialize_comment(comment)
    assert result["body"] == "Nice post"


def test_serialize_comment_none():
    import app.models.forum_post as pm
    assert pm.serialize_comment(None) is None


def test_author_fields_no_id(monkeypatch):
    import app.models.forum_post as pm
    result = pm._author_fields(None)
    assert result == {"author_name": "", "author_photo_url": ""}


def test_author_fields_not_found(monkeypatch):
    import app.models.forum_post as pm
    mock = MagicMock()
    mock.return_value.find_one.return_value = None
    monkeypatch.setattr("app.models.forum_post.users_col", mock)
    result = pm._author_fields(str(ObjectId()))
    assert result == {"author_name": "", "author_photo_url": ""}


def test_author_fields_email_fallback(monkeypatch):
    import app.models.forum_post as pm
    user = {"_id": ObjectId(), "name": "", "email": "a@b.com", "photo_url": ""}
    mock = MagicMock()
    mock.return_value.find_one.return_value = user
    monkeypatch.setattr("app.models.forum_post.users_col", mock)
    result = pm._author_fields(str(ObjectId()))
    assert result["author_name"] == "a@b.com"


# ══════════════════════════════════════════════════════════════════════════════
# forum_question model
# ══════════════════════════════════════════════════════════════════════════════

def test_create_question(monkeypatch):
    import app.models.forum_question as qm
    qid = ObjectId()
    mock = MagicMock()
    mock.return_value.insert_one.return_value = MagicMock(inserted_id=qid)
    monkeypatch.setattr("app.models.forum_question.forum_questions_col", mock)
    result = qm.create_question(str(ObjectId()), "Title", "Body",
                                crop_tags=["tomato"], disease_tags=["blight"])
    assert result["title"] == "Title"
    assert result["_id"] == qid


def test_create_answer(monkeypatch):
    import app.models.forum_question as qm
    mock_ans = MagicMock()
    mock_ans.return_value.insert_one.return_value = MagicMock(inserted_id=ObjectId())
    mock_qst = MagicMock()
    mock_qst.return_value.update_one.return_value = None
    monkeypatch.setattr("app.models.forum_question.forum_answers_col", mock_ans)
    monkeypatch.setattr("app.models.forum_question.forum_questions_col", mock_qst)
    result = qm.create_answer(str(ObjectId()), str(ObjectId()), "Use copper fungicide")
    assert result["body"] == "Use copper fungicide"


def test_accept_answer_success(monkeypatch):
    import app.models.forum_question as qm
    author_id = ObjectId()
    question = {"_id": ObjectId(), "author_id": author_id}
    mock_q = MagicMock()
    mock_q.return_value.find_one.return_value = question
    mock_q.return_value.update_one.return_value = None
    mock_a = MagicMock()
    mock_a.return_value.update_many.return_value = None
    mock_a.return_value.update_one.return_value = None
    monkeypatch.setattr("app.models.forum_question.forum_questions_col", mock_q)
    monkeypatch.setattr("app.models.forum_question.forum_answers_col", mock_a)
    result = qm.accept_answer(str(ObjectId()), str(question["_id"]), str(author_id))
    assert result is True


def test_accept_answer_not_found(monkeypatch):
    import app.models.forum_question as qm
    mock_q = MagicMock()
    mock_q.return_value.find_one.return_value = None
    monkeypatch.setattr("app.models.forum_question.forum_questions_col", mock_q)
    result = qm.accept_answer(str(ObjectId()), str(ObjectId()), "some_user")
    assert result is False


def test_accept_answer_wrong_user(monkeypatch):
    import app.models.forum_question as qm
    author_id = ObjectId()
    question = {"_id": ObjectId(), "author_id": author_id}
    mock_q = MagicMock()
    mock_q.return_value.find_one.return_value = question
    monkeypatch.setattr("app.models.forum_question.forum_questions_col", mock_q)
    result = qm.accept_answer(str(ObjectId()), str(question["_id"]), "different_user")
    assert result is False


def test_get_questions(monkeypatch):
    import app.models.forum_question as qm
    question = {"_id": ObjectId(), "title": "Q", "created_at": datetime.now(timezone.utc)}

    mock_q = MagicMock()
    chain = MagicMock()
    chain.sort.return_value = chain
    chain.skip.return_value = chain
    chain.limit.return_value = [question]
    mock_q.return_value.find.return_value = chain
    monkeypatch.setattr("app.models.forum_question.forum_questions_col", mock_q)

    result = qm.get_questions(crop_tags=["tomato"])
    assert len(result) == 1


def test_get_questions_answered_by(monkeypatch):
    import app.models.forum_question as qm
    uid = str(ObjectId())
    qid = ObjectId()

    mock_a = MagicMock()
    mock_a.return_value.find.return_value = [{"question_id": qid}]
    monkeypatch.setattr("app.models.forum_question.forum_answers_col", mock_a)

    mock_q = MagicMock()
    chain = MagicMock()
    chain.sort.return_value = chain
    chain.skip.return_value = chain
    chain.limit.return_value = []
    mock_q.return_value.find.return_value = chain
    monkeypatch.setattr("app.models.forum_question.forum_questions_col", mock_q)

    result = qm.get_questions(answered_by=uid)
    assert result == []


def test_get_answers(monkeypatch):
    import app.models.forum_question as qm
    answer = {"_id": ObjectId(), "body": "Answer", "created_at": datetime.now(timezone.utc)}
    mock_a = MagicMock()
    chain = MagicMock()
    chain.sort.return_value = [answer]
    mock_a.return_value.find.return_value = chain
    monkeypatch.setattr("app.models.forum_question.forum_answers_col", mock_a)
    result = qm.get_answers(str(ObjectId()))
    assert len(result) == 1


def test_get_question_by_id(monkeypatch):
    import app.models.forum_question as qm
    qid = ObjectId()
    question = {"_id": qid, "title": "Q"}
    mock_q = MagicMock()
    mock_q.return_value.find_one.return_value = question
    monkeypatch.setattr("app.models.forum_question.forum_questions_col", mock_q)
    result = qm.get_question_by_id(str(qid))
    assert result["title"] == "Q"


def test_serialize_question(monkeypatch):
    import app.models.forum_question as qm
    monkeypatch.setattr("app.models.forum_question.users_col", lambda: MagicMock(
        find_one=lambda q: None
    ))
    q = {
        "_id": ObjectId(), "author_id": ObjectId(), "title": "T", "body": "B",
        "tags": {}, "answer_count": 0, "is_resolved": False, "accepted_answer_id": None,
        "created_at": datetime.now(timezone.utc),
    }
    result = qm.serialize_question(q)
    assert result["title"] == "T"
    assert result["is_resolved"] is False


def test_serialize_question_with_accepted(monkeypatch):
    import app.models.forum_question as qm
    monkeypatch.setattr("app.models.forum_question.users_col", lambda: MagicMock(
        find_one=lambda q: None
    ))
    aid = ObjectId()
    q = {
        "_id": ObjectId(), "author_id": ObjectId(), "title": "T", "body": "B",
        "tags": {}, "answer_count": 1, "is_resolved": True, "accepted_answer_id": aid,
        "created_at": datetime.now(timezone.utc),
    }
    result = qm.serialize_question(q)
    assert result["accepted_answer_id"] == str(aid)


def test_serialize_question_none():
    import app.models.forum_question as qm
    assert qm.serialize_question(None) is None


def test_serialize_answer(monkeypatch):
    import app.models.forum_question as qm
    monkeypatch.setattr("app.models.forum_question.users_col", lambda: MagicMock(
        find_one=lambda q: None
    ))
    a = {
        "_id": ObjectId(), "question_id": ObjectId(), "author_id": ObjectId(),
        "body": "Ans", "is_accepted": True, "upvotes": 3,
        "created_at": datetime.now(timezone.utc),
    }
    result = qm.serialize_answer(a)
    assert result["is_accepted"] is True
    assert result["upvotes"] == 3


def test_serialize_answer_none():
    import app.models.forum_question as qm
    assert qm.serialize_answer(None) is None


# ══════════════════════════════════════════════════════════════════════════════
# community model
# ══════════════════════════════════════════════════════════════════════════════

def test_ensure_community_creates_new(monkeypatch):
    import app.models.community as cm
    cid = ObjectId()
    mock = MagicMock()
    mock.return_value.find_one.return_value = None
    mock.return_value.insert_one.return_value = MagicMock(inserted_id=cid)
    monkeypatch.setattr("app.models.community.communities_col", mock)
    result = cm._ensure_community("tomato")
    assert result["crop_slug"] == "tomato"


def test_ensure_community_returns_existing(monkeypatch):
    import app.models.community as cm
    existing = {"_id": ObjectId(), "crop_slug": "tomato"}
    mock = MagicMock()
    mock.return_value.find_one.return_value = existing
    monkeypatch.setattr("app.models.community.communities_col", mock)
    result = cm._ensure_community("tomato")
    assert result == existing


def test_auto_subscribe(monkeypatch):
    import app.models.community as cm
    mock = MagicMock()
    mock.return_value.find_one.return_value = {"_id": ObjectId(), "crop_slug": "wheat"}
    mock.return_value.update_one.return_value = None
    monkeypatch.setattr("app.models.community.communities_col", mock)
    cm.auto_subscribe("user123", "wheat")
    mock.return_value.update_one.assert_called_once()


def test_auto_subscribe_empty_slug(monkeypatch):
    import app.models.community as cm
    mock = MagicMock()
    monkeypatch.setattr("app.models.community.communities_col", mock)
    cm.auto_subscribe("user123", "")
    mock.return_value.find_one.assert_not_called()


def test_get_all_communities(monkeypatch):
    import app.models.community as cm
    mock = MagicMock()
    chain = MagicMock()
    chain.sort.return_value = [{"_id": ObjectId(), "crop_slug": "tomato"}]
    mock.return_value.find.return_value = chain
    monkeypatch.setattr("app.models.community.communities_col", mock)
    result = cm.get_all_communities()
    assert len(result) == 1


def test_get_community(monkeypatch):
    import app.models.community as cm
    doc = {"_id": ObjectId(), "crop_slug": "wheat"}
    mock = MagicMock()
    mock.return_value.find_one.return_value = doc
    monkeypatch.setattr("app.models.community.communities_col", mock)
    result = cm.get_community("wheat")
    assert result["crop_slug"] == "wheat"


def test_get_user_communities(monkeypatch):
    import app.models.community as cm
    mock = MagicMock()
    mock.return_value.find.return_value = []
    monkeypatch.setattr("app.models.community.communities_col", mock)
    result = cm.get_user_communities("user123")
    assert result == []


def test_serialize_community(monkeypatch):
    import app.models.community as cm
    doc = {
        "_id": ObjectId(), "crop_slug": "tomato", "display_name": "Tomato",
        "member_count": 5, "trending_diseases": [], "pinned_post_ids": [],
        "created_at": datetime.now(timezone.utc),
    }
    result = cm.serialize(doc)
    assert result["crop_slug"] == "tomato"
    assert result["member_count"] == 5


def test_serialize_community_none():
    import app.models.community as cm
    assert cm.serialize(None) is None


# ══════════════════════════════════════════════════════════════════════════════
# article_model
# ══════════════════════════════════════════════════════════════════════════════

def test_create_article(monkeypatch):
    import app.models.article_model as am
    aid = ObjectId()
    mock = MagicMock()
    mock.return_value.insert_one.return_value = MagicMock(inserted_id=aid)
    monkeypatch.setattr("app.models.article_model.articles_col", mock)
    result = am.create_article("Title", "Body", str(ObjectId()),
                               category="disease", image_url="http://img.png", published=True)
    assert result["title"] == "Title"
    assert result["published"] is True


def test_get_all_articles(monkeypatch):
    import app.models.article_model as am
    article = {"_id": ObjectId(), "title": "A"}
    mock = MagicMock()
    chain = MagicMock()
    chain.sort.return_value = chain
    chain.skip.return_value = chain
    chain.limit.return_value = [article]
    mock.return_value.find.return_value = chain
    monkeypatch.setattr("app.models.article_model.articles_col", mock)
    result = am.get_all_articles()
    assert len(result) == 1


def test_get_published_articles(monkeypatch):
    import app.models.article_model as am
    mock = MagicMock()
    chain = MagicMock()
    chain.sort.return_value = chain
    chain.skip.return_value = chain
    chain.limit.return_value = []
    mock.return_value.find.return_value = chain
    monkeypatch.setattr("app.models.article_model.articles_col", mock)
    result = am.get_published_articles(category="tips")
    assert result == []


def test_get_article_by_id(monkeypatch):
    import app.models.article_model as am
    aid = ObjectId()
    mock = MagicMock()
    mock.return_value.find_one.return_value = {"_id": aid, "title": "X"}
    monkeypatch.setattr("app.models.article_model.articles_col", mock)
    result = am.get_article_by_id(str(aid))
    assert result["title"] == "X"


def test_update_article(monkeypatch):
    import app.models.article_model as am
    mock = MagicMock()
    mock.return_value.update_one.return_value = MagicMock(modified_count=1)
    monkeypatch.setattr("app.models.article_model.articles_col", mock)
    result = am.update_article(str(ObjectId()), {"title": "New"})
    assert result is True


def test_delete_article(monkeypatch):
    import app.models.article_model as am
    mock = MagicMock()
    mock.return_value.delete_one.return_value = MagicMock(deleted_count=1)
    monkeypatch.setattr("app.models.article_model.articles_col", mock)
    assert am.delete_article(str(ObjectId())) is True


def test_delete_article_not_found(monkeypatch):
    import app.models.article_model as am
    mock = MagicMock()
    mock.return_value.delete_one.return_value = MagicMock(deleted_count=0)
    monkeypatch.setattr("app.models.article_model.articles_col", mock)
    assert am.delete_article(str(ObjectId())) is False


def test_count_articles(monkeypatch):
    import app.models.article_model as am
    mock = MagicMock()
    mock.return_value.count_documents.return_value = 7
    monkeypatch.setattr("app.models.article_model.articles_col", mock)
    assert am.count_articles() == 7
    assert am.count_articles(published_only=True) == 7


def test_serialize_article():
    import app.models.article_model as am
    article = {
        "_id": ObjectId(), "title": "T", "body": "B",
        "author_id": ObjectId(), "category": "disease",
        "image_url": "http://img.jpg", "published": True,
        "created_at": datetime.now(timezone.utc),
        "updated_at": datetime.now(timezone.utc),
    }
    result = am.serialize(article)
    assert result["title"] == "T"
    assert result["published"] is True


def test_serialize_article_none():
    import app.models.article_model as am
    assert am.serialize(None) is None
