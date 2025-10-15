-- PostgreSQL Procedures for Newzzz News Application

-- 1. BanUser Procedure
-- Sets user's Is_Active status to FALSE and removes all comments they have posted
CREATE OR REPLACE PROCEDURE BanUser(user_id_param INTEGER)
LANGUAGE plpgsql AS $$
DECLARE
    user_exists BOOLEAN;
    affected_comments INTEGER;
BEGIN
    -- Check if user exists and is currently active
    SELECT EXISTS (
        SELECT 1 FROM Users_Table 
        WHERE User_ID = user_id_param AND Is_Active = TRUE
    ) INTO user_exists;
    
    IF NOT user_exists THEN
        RAISE EXCEPTION 'User with ID % does not exist or is already inactive.', user_id_param;
    END IF;
    
    -- Count comments to be removed
    SELECT COUNT(*) INTO affected_comments
    FROM Comments
    WHERE User_ID = user_id_param;
    
    -- Remove all comments by the user
    DELETE FROM Comments WHERE User_ID = user_id_param;
    
    -- Deactivate the user
    UPDATE Users_Table 
    SET Is_Active = FALSE, Updated_At = CURRENT_TIMESTAMP
    WHERE User_ID = user_id_param;
    
    -- Log the action
    INSERT INTO Admin_Audit (Action, Target_Table, Target_ID, Old_Values, New_Values, Action_Date)
    VALUES (
        'BAN_USER',
        'Users_Table',
        user_id_param,
        jsonb_build_object('is_active', true, 'comments_count', affected_comments),
        jsonb_build_object('is_active', false, 'comments_removed', affected_comments),
        CURRENT_TIMESTAMP
    );
    
    RAISE NOTICE 'User % has been banned and % comments have been removed.', user_id_param, affected_comments;
END;
$$;

-- 2. MergeNewsSources Procedure
-- Reassigns all articles from old source to new source and deletes the old source
CREATE OR REPLACE PROCEDURE MergeNewsSources(old_source_id INTEGER, new_source_id INTEGER)
LANGUAGE plpgsql AS $$
DECLARE
    old_source_exists BOOLEAN;
    new_source_exists BOOLEAN;
    articles_moved INTEGER;
BEGIN
    -- Check if both sources exist
    SELECT EXISTS (SELECT 1 FROM News_Sources WHERE News_Source_ID = old_source_id) INTO old_source_exists;
    SELECT EXISTS (SELECT 1 FROM News_Sources WHERE News_Source_ID = new_source_id) INTO new_source_exists;
    
    IF NOT old_source_exists THEN
        RAISE EXCEPTION 'Old news source with ID % does not exist.', old_source_id;
    END IF;
    
    IF NOT new_source_exists THEN
        RAISE EXCEPTION 'New news source with ID % does not exist.', new_source_id;
    END IF;
    
    IF old_source_id = new_source_id THEN
        RAISE EXCEPTION 'Cannot merge a news source with itself.';
    END IF;
    
    -- Count articles to be moved
    SELECT COUNT(*) INTO articles_moved
    FROM Articles
    WHERE News_Source_ID = old_source_id;
    
    -- Reassign all articles from old source to new source
    UPDATE Articles 
    SET News_Source_ID = new_source_id, Updated_At = CURRENT_TIMESTAMP
    WHERE News_Source_ID = old_source_id;
    
    -- Delete the old news source
    DELETE FROM News_Sources WHERE News_Source_ID = old_source_id;
    
    -- Log the action
    INSERT INTO Admin_Audit (Action, Target_Table, Target_ID, Old_Values, New_Values, Action_Date)
    VALUES (
        'MERGE_NEWS_SOURCES',
        'News_Sources',
        old_source_id,
        jsonb_build_object('old_source_id', old_source_id, 'articles_count', articles_moved),
        jsonb_build_object('new_source_id', new_source_id, 'articles_moved', articles_moved),
        CURRENT_TIMESTAMP
    );
    
    RAISE NOTICE 'Merged news source %. % articles moved to source %.', old_source_id, articles_moved, new_source_id;
END;
$$;

-- 3. ApproveComment Procedure
-- Changes a comment's Is_Approved status to TRUE
CREATE OR REPLACE PROCEDURE ApproveComment(comment_id_param INTEGER)
LANGUAGE plpgsql AS $$
DECLARE
    comment_exists BOOLEAN;
    current_status BOOLEAN;
BEGIN
    -- Check if comment exists and get current status
    SELECT Is_Approved INTO current_status
    FROM Comments
    WHERE Comment_ID = comment_id_param;
    
    IF current_status IS NULL THEN
        RAISE EXCEPTION 'Comment with ID % does not exist.', comment_id_param;
    END IF;
    
    IF current_status = TRUE THEN
        RAISE NOTICE 'Comment % is already approved.', comment_id_param;
        RETURN;
    END IF;
    
    -- Approve the comment
    UPDATE Comments 
    SET Is_Approved = TRUE, Updated_At = CURRENT_TIMESTAMP
    WHERE Comment_ID = comment_id_param;
    
    -- Log the action
    INSERT INTO Admin_Audit (Action, Target_Table, Target_ID, Old_Values, New_Values, Action_Date)
    VALUES (
        'APPROVE_COMMENT',
        'Comments',
        comment_id_param,
        jsonb_build_object('is_approved', false),
        jsonb_build_object('is_approved', true),
        CURRENT_TIMESTAMP
    );
    
    RAISE NOTICE 'Comment % has been approved.', comment_id_param;
END;
$$;

-- 4. ChangeUserPassword Procedure
-- Updates a user's password hash after verifying the old password
CREATE OR REPLACE PROCEDURE ChangeUserPassword(
    user_id_param INTEGER, 
    old_password_hash VARCHAR, 
    new_password_hash VARCHAR
)
LANGUAGE plpgsql AS $$
DECLARE
    current_password_hash VARCHAR;
    user_active BOOLEAN;
BEGIN
    -- Get current password hash and check if user is active
    SELECT Password_Hash, Is_Active
    INTO current_password_hash, user_active
    FROM Users_Table
    WHERE User_ID = user_id_param;
    
    IF current_password_hash IS NULL THEN
        RAISE EXCEPTION 'User with ID % does not exist.', user_id_param;
    END IF;
    
    IF NOT user_active THEN
        RAISE EXCEPTION 'Cannot change password for inactive user.';
    END IF;
    
    -- Verify old password
    IF current_password_hash != old_password_hash THEN
        RAISE EXCEPTION 'Old password is incorrect.';
    END IF;
    
    -- Update password
    UPDATE Users_Table 
    SET Password_Hash = new_password_hash, Updated_At = CURRENT_TIMESTAMP
    WHERE User_ID = user_id_param;
    
    -- Log the action (without storing actual password hashes for security)
    INSERT INTO Admin_Audit (Action, Target_Table, Target_ID, Old_Values, New_Values, Action_Date)
    VALUES (
        'CHANGE_PASSWORD',
        'Users_Table',
        user_id_param,
        jsonb_build_object('password_changed', false),
        jsonb_build_object('password_changed', true),
        CURRENT_TIMESTAMP
    );
    
    RAISE NOTICE 'Password changed successfully for user %.', user_id_param;
END;
$$;

-- 5. AssignArticleToCategory Procedure
-- Creates an entry in Article_Categories table to link article with category
CREATE OR REPLACE PROCEDURE AssignArticleToCategory(article_id_param INTEGER, category_id_param INTEGER)
LANGUAGE plpgsql AS $$
DECLARE
    article_exists BOOLEAN;
    category_exists BOOLEAN;
    already_assigned BOOLEAN;
BEGIN
    -- Check if article exists and is published
    SELECT EXISTS (
        SELECT 1 FROM Articles 
        WHERE Article_ID = article_id_param AND Is_Published = TRUE
    ) INTO article_exists;
    
    IF NOT article_exists THEN
        RAISE EXCEPTION 'Article with ID % does not exist or is not published.', article_id_param;
    END IF;
    
    -- Check if category exists
    SELECT EXISTS (
        SELECT 1 FROM Categories 
        WHERE Category_ID = category_id_param
    ) INTO category_exists;
    
    IF NOT category_exists THEN
        RAISE EXCEPTION 'Category with ID % does not exist.', category_id_param;
    END IF;
    
    -- Check if already assigned
    SELECT EXISTS (
        SELECT 1 FROM Article_Categories 
        WHERE Article_ID = article_id_param AND Category_ID = category_id_param
    ) INTO already_assigned;
    
    IF already_assigned THEN
        RAISE NOTICE 'Article % is already assigned to category %.', article_id_param, category_id_param;
        RETURN;
    END IF;
    
    -- Create the assignment
    INSERT INTO Article_Categories (Article_ID, Category_ID)
    VALUES (article_id_param, category_id_param);
    
    -- Log the action
    INSERT INTO Admin_Audit (Action, Target_Table, Target_ID, Old_Values, New_Values, Action_Date)
    VALUES (
        'ASSIGN_ARTICLE_CATEGORY',
        'Article_Categories',
        article_id_param,
        jsonb_build_object('assigned', false),
        jsonb_build_object('article_id', article_id_param, 'category_id', category_id_param, 'assigned', true),
        CURRENT_TIMESTAMP
    );
    
    RAISE NOTICE 'Article % assigned to category %.', article_id_param, category_id_param;
END;
$$;

-- 6. PurgeOldActivities Procedure
-- Deletes records from User_Activities table older than specified duration
CREATE OR REPLACE PROCEDURE PurgeOldActivities(months_old INTEGER DEFAULT 24)
LANGUAGE plpgsql AS $$
DECLARE
    cutoff_date TIMESTAMP;
    activities_deleted INTEGER;
    views_deleted INTEGER;
    likes_deleted INTEGER;
    shares_deleted INTEGER;
BEGIN
    IF months_old <= 0 THEN
        RAISE EXCEPTION 'Months parameter must be positive.';
    END IF;
    
    -- Calculate cutoff date
    cutoff_date := CURRENT_TIMESTAMP - (months_old || ' months')::INTERVAL;
    
    -- Delete from specialized tables first due to foreign key constraints
    DELETE FROM Views 
    WHERE Activity_ID IN (
        SELECT Activity_ID FROM User_Activities 
        WHERE Activity_Date < cutoff_date
    );
    GET DIAGNOSTICS views_deleted = ROW_COUNT;
    
    DELETE FROM Likes 
    WHERE Activity_ID IN (
        SELECT Activity_ID FROM User_Activities 
        WHERE Activity_Date < cutoff_date
    );
    GET DIAGNOSTICS likes_deleted = ROW_COUNT;
    
    DELETE FROM Shares 
    WHERE Activity_ID IN (
        SELECT Activity_ID FROM User_Activities 
        WHERE Activity_Date < cutoff_date
    );
    GET DIAGNOSTICS shares_deleted = ROW_COUNT;
    
    -- Delete from main User_Activities table
    DELETE FROM User_Activities WHERE Activity_Date < cutoff_date;
    GET DIAGNOSTICS activities_deleted = ROW_COUNT;
    
    -- Log the action
    INSERT INTO Admin_Audit (Action, Target_Table, Target_ID, Old_Values, New_Values, Action_Date)
    VALUES (
        'PURGE_OLD_ACTIVITIES',
        'User_Activities',
        NULL,
        jsonb_build_object('cutoff_date', cutoff_date, 'months_old', months_old),
        jsonb_build_object(
            'activities_deleted', activities_deleted,
            'views_deleted', views_deleted,
            'likes_deleted', likes_deleted,
            'shares_deleted', shares_deleted
        ),
        CURRENT_TIMESTAMP
    );
    
    RAISE NOTICE 'Purged % activities older than % months. Details: % views, % likes, % shares deleted.', 
        activities_deleted, months_old, views_deleted, likes_deleted, shares_deleted;
END;
$$;

-- Additional useful procedures

-- 7. UpdateArticleMetricsManually Procedure
-- Manually recalculates and updates article metrics
CREATE OR REPLACE PROCEDURE UpdateArticleMetricsManually(article_id_param INTEGER)
LANGUAGE plpgsql AS $$
DECLARE
    new_views INTEGER := 0;
    new_likes INTEGER := 0;
    new_shares INTEGER := 0;
    article_exists BOOLEAN;
BEGIN
    -- Check if article exists
    SELECT EXISTS (SELECT 1 FROM Articles WHERE Article_ID = article_id_param) INTO article_exists;
    
    IF NOT article_exists THEN
        RAISE EXCEPTION 'Article with ID % does not exist.', article_id_param;
    END IF;
    
    -- Count views
    SELECT COUNT(*) INTO new_views
    FROM User_Activities
    WHERE Article_ID = article_id_param AND Activity_Type = 'view';
    
    -- Count likes
    SELECT COUNT(*) INTO new_likes
    FROM User_Activities
    WHERE Article_ID = article_id_param AND Activity_Type = 'like';
    
    -- Count shares
    SELECT COUNT(*) INTO new_shares
    FROM User_Activities
    WHERE Article_ID = article_id_param AND Activity_Type = 'share';
    
    -- Update article metrics
    UPDATE Articles 
    SET Views = new_views, 
        Likes = new_likes, 
        Shares = new_shares, 
        Updated_At = CURRENT_TIMESTAMP
    WHERE Article_ID = article_id_param;
    
    RAISE NOTICE 'Updated metrics for article %: % views, % likes, % shares.', 
        article_id_param, new_views, new_likes, new_shares;
END;
$$;

-- 8. CleanupUnusedCategories Procedure
-- Removes categories that have no associated articles
CREATE OR REPLACE PROCEDURE CleanupUnusedCategories()
LANGUAGE plpgsql AS $$
DECLARE
    categories_deleted INTEGER;
BEGIN
    -- Delete categories with no associated articles
    DELETE FROM Categories 
    WHERE Category_ID NOT IN (
        SELECT DISTINCT Category_ID 
        FROM Article_Categories ac
        JOIN Articles a ON ac.Article_ID = a.Article_ID
        WHERE a.Is_Published = TRUE
    );
    GET DIAGNOSTICS categories_deleted = ROW_COUNT;
    
    -- Log the action
    INSERT INTO Admin_Audit (Action, Target_Table, Target_ID, Old_Values, New_Values, Action_Date)
    VALUES (
        'CLEANUP_UNUSED_CATEGORIES',
        'Categories',
        NULL,
        jsonb_build_object('action', 'cleanup_unused'),
        jsonb_build_object('categories_deleted', categories_deleted),
        CURRENT_TIMESTAMP
    );
    
    RAISE NOTICE 'Cleaned up % unused categories.', categories_deleted;
END;
$$;

-- 9. ArchiveOldArticles Procedure
-- Archives articles older than specified months by unpublishing them
CREATE OR REPLACE PROCEDURE ArchiveOldArticles(months_old INTEGER DEFAULT 36)
LANGUAGE plpgsql AS $$
DECLARE
    cutoff_date TIMESTAMP;
    articles_archived INTEGER;
BEGIN
    IF months_old <= 0 THEN
        RAISE EXCEPTION 'Months parameter must be positive.';
    END IF;
    
    cutoff_date := CURRENT_TIMESTAMP - (months_old || ' months')::INTERVAL;
    
    -- Archive old published articles
    UPDATE Articles 
    SET Is_Published = FALSE, Updated_At = CURRENT_TIMESTAMP
    WHERE Publication_Date < cutoff_date AND Is_Published = TRUE;
    GET DIAGNOSTICS articles_archived = ROW_COUNT;
    
    -- Log the action
    INSERT INTO Admin_Audit (Action, Target_Table, Target_ID, Old_Values, New_Values, Action_Date)
    VALUES (
        'ARCHIVE_OLD_ARTICLES',
        'Articles',
        NULL,
        jsonb_build_object('cutoff_date', cutoff_date, 'months_old', months_old),
        jsonb_build_object('articles_archived', articles_archived),
        CURRENT_TIMESTAMP
    );
    
    RAISE NOTICE 'Archived % articles older than % months.', articles_archived, months_old;
END;
$$;

-- Comments for documentation
COMMENT ON PROCEDURE BanUser(INTEGER) IS 'Bans a user by deactivating account and removing comments';
COMMENT ON PROCEDURE MergeNewsSources(INTEGER, INTEGER) IS 'Merges two news sources by reassigning articles';
COMMENT ON PROCEDURE ApproveComment(INTEGER) IS 'Approves a comment for public display';
COMMENT ON PROCEDURE ChangeUserPassword(INTEGER, VARCHAR, VARCHAR) IS 'Changes user password after verification';
COMMENT ON PROCEDURE AssignArticleToCategory(INTEGER, INTEGER) IS 'Assigns an article to a category';
COMMENT ON PROCEDURE PurgeOldActivities(INTEGER) IS 'Removes old user activity records for maintenance';
COMMENT ON PROCEDURE UpdateArticleMetricsManually(INTEGER) IS 'Manually recalculates article engagement metrics';
COMMENT ON PROCEDURE CleanupUnusedCategories() IS 'Removes categories with no associated articles';
COMMENT ON PROCEDURE ArchiveOldArticles(INTEGER) IS 'Archives old articles by unpublishing them';
