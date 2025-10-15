-- PostgreSQL Functions for Newzzz News Application

-- 1. GetArticleLikeCount Function
-- Returns the total number of likes for a specific article
CREATE OR REPLACE FUNCTION GetArticleLikeCount(article_id_param INTEGER)
RETURNS INTEGER AS $$
DECLARE
    like_count INTEGER;
BEGIN
    SELECT COUNT(*)
    INTO like_count
    FROM User_Activities ua
    WHERE ua.Article_ID = article_id_param 
    AND ua.Activity_Type = 'like';
    
    RETURN COALESCE(like_count, 0);
END;
$$ LANGUAGE plpgsql;

-- 2. CheckIfUsernameExists Function
-- Returns TRUE if username exists, FALSE otherwise
CREATE OR REPLACE FUNCTION CheckIfUsernameExists(username_param VARCHAR)
RETURNS BOOLEAN AS $$
DECLARE
    username_exists BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM Users_Table 
        WHERE Username = username_param
    ) INTO username_exists;
    
    RETURN username_exists;
END;
$$ LANGUAGE plpgsql;

-- 3. CalculateUserActivityScore Function
-- Returns a numerical score based on user's total comments, likes, and shares
CREATE OR REPLACE FUNCTION CalculateUserActivityScore(user_id_param INTEGER)
RETURNS INTEGER AS $$
DECLARE
    comment_count INTEGER := 0;
    like_count INTEGER := 0;
    share_count INTEGER := 0;
    view_count INTEGER := 0;
    total_score INTEGER := 0;
BEGIN
    -- Count comments (weight: 5 points each)
    SELECT COUNT(*)
    INTO comment_count
    FROM Comments
    WHERE User_ID = user_id_param AND Is_Approved = TRUE;
    
    -- Count likes (weight: 2 points each)
    SELECT COUNT(*)
    INTO like_count
    FROM User_Activities
    WHERE User_ID = user_id_param AND Activity_Type = 'like';
    
    -- Count shares (weight: 3 points each)
    SELECT COUNT(*)
    INTO share_count
    FROM User_Activities
    WHERE User_ID = user_id_param AND Activity_Type = 'share';
    
    -- Count views (weight: 1 point each)
    SELECT COUNT(*)
    INTO view_count
    FROM User_Activities
    WHERE User_ID = user_id_param AND Activity_Type = 'view';
    
    -- Calculate weighted score
    total_score := (comment_count * 5) + (like_count * 2) + (share_count * 3) + (view_count * 1);
    
    RETURN total_score;
END;
$$ LANGUAGE plpgsql;

-- 4. GetUserSubscriptionStatus Function
-- Returns 1 if user has active subscription to category, 0 otherwise
CREATE OR REPLACE FUNCTION GetUserSubscriptionStatus(user_id_param INTEGER, category_id_param INTEGER)
RETURNS INTEGER AS $$
DECLARE
    is_subscribed INTEGER;
BEGIN
    SELECT CASE 
        WHEN COUNT(*) > 0 THEN 1 
        ELSE 0 
    END
    INTO is_subscribed
    FROM Subscriptions
    WHERE User_ID = user_id_param 
    AND Category_ID = category_id_param 
    AND Is_Active = TRUE;
    
    RETURN is_subscribed;
END;
$$ LANGUAGE plpgsql;

-- 5. GetCommentCountForArticle Function
-- Returns the total number of approved comments for an article
CREATE OR REPLACE FUNCTION GetCommentCountForArticle(article_id_param INTEGER)
RETURNS INTEGER AS $$
DECLARE
    comment_count INTEGER;
BEGIN
    SELECT COUNT(*)
    INTO comment_count
    FROM Comments
    WHERE Article_ID = article_id_param 
    AND Is_Approved = TRUE;
    
    RETURN COALESCE(comment_count, 0);
END;
$$ LANGUAGE plpgsql;

-- 6. IsArticleReported Function
-- Returns TRUE if there are pending reports for an article, FALSE otherwise
CREATE OR REPLACE FUNCTION IsArticleReported(article_id_param INTEGER)
RETURNS BOOLEAN AS $$
DECLARE
    has_pending_reports BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM Reports 
        WHERE Article_ID = article_id_param 
        AND Status = 'pending'
    ) INTO has_pending_reports;
    
    RETURN has_pending_reports;
END;
$$ LANGUAGE plpgsql;

-- Additional useful functions

-- 7. GetArticleEngagementScore Function
-- Calculates engagement score based on views, likes, shares, and comments
CREATE OR REPLACE FUNCTION GetArticleEngagementScore(article_id_param INTEGER)
RETURNS DECIMAL AS $$
DECLARE
    view_count INTEGER := 0;
    like_count INTEGER := 0;
    share_count INTEGER := 0;
    comment_count INTEGER := 0;
    engagement_score DECIMAL := 0.0;
BEGIN
    -- Get article metrics
    SELECT Views, Likes, Shares 
    INTO view_count, like_count, share_count
    FROM Articles 
    WHERE Article_ID = article_id_param;
    
    -- Get comment count
    SELECT GetCommentCountForArticle(article_id_param) INTO comment_count;
    
    -- Calculate engagement score with weights
    engagement_score := (view_count * 0.1) + (like_count * 2.0) + (share_count * 3.0) + (comment_count * 5.0);
    
    RETURN ROUND(engagement_score, 2);
END;
$$ LANGUAGE plpgsql;

-- 8. GetUserRoleType Function
-- Returns user role type: 'admin', 'regular', or 'inactive'
CREATE OR REPLACE FUNCTION GetUserRoleType(user_id_param INTEGER)
RETURNS TEXT AS $$
DECLARE
    user_active BOOLEAN;
    is_admin BOOLEAN;
    role_type TEXT;
BEGIN
    -- Check if user is active
    SELECT Is_Active INTO user_active
    FROM Users_Table
    WHERE User_ID = user_id_param;
    
    IF NOT user_active OR user_active IS NULL THEN
        RETURN 'inactive';
    END IF;
    
    -- Check if user is admin
    SELECT EXISTS (
        SELECT 1 FROM Admins 
        WHERE Admin_ID = user_id_param
    ) INTO is_admin;
    
    IF is_admin THEN
        RETURN 'admin';
    ELSE
        RETURN 'regular';
    END IF;
END;
$$ LANGUAGE plpgsql;

-- 9. GetCategoryArticleCount Function
-- Returns the number of published articles in a category
CREATE OR REPLACE FUNCTION GetCategoryArticleCount(category_id_param INTEGER)
RETURNS INTEGER AS $$
DECLARE
    article_count INTEGER;
BEGIN
    SELECT COUNT(*)
    INTO article_count
    FROM Article_Categories ac
    JOIN Articles a ON ac.Article_ID = a.Article_ID
    WHERE ac.Category_ID = category_id_param 
    AND a.Is_Published = TRUE;
    
    RETURN COALESCE(article_count, 0);
END;
$$ LANGUAGE plpgsql;

-- 10. ValidateUserCredentials Function
-- Returns user ID if credentials are valid, -1 otherwise
CREATE OR REPLACE FUNCTION ValidateUserCredentials(email_param VARCHAR, password_hash_param VARCHAR)
RETURNS INTEGER AS $$
DECLARE
    user_id INTEGER;
BEGIN
    SELECT User_ID
    INTO user_id
    FROM Users_Table
    WHERE Email = email_param 
    AND Password_Hash = password_hash_param 
    AND Is_Active = TRUE;
    
    RETURN COALESCE(user_id, -1);
END;
$$ LANGUAGE plpgsql;

-- 11. GetTopCategories Function
-- Returns top N categories by article count
CREATE OR REPLACE FUNCTION GetTopCategories(limit_param INTEGER DEFAULT 10)
RETURNS TABLE (
    category_id INTEGER,
    category_name VARCHAR,
    article_count BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.Category_ID,
        c.Category_Name,
        COUNT(ac.Article_ID) as article_count
    FROM Categories c
    LEFT JOIN Article_Categories ac ON c.Category_ID = ac.Category_ID
    LEFT JOIN Articles a ON ac.Article_ID = a.Article_ID AND a.Is_Published = TRUE
    GROUP BY c.Category_ID, c.Category_Name
    ORDER BY article_count DESC
    LIMIT limit_param;
END;
$$ LANGUAGE plpgsql;

-- 12. GetRecentActivity Function
-- Returns recent user activity for a specific user
CREATE OR REPLACE FUNCTION GetRecentActivity(user_id_param INTEGER, days_back INTEGER DEFAULT 7)
RETURNS TABLE (
    activity_date TIMESTAMP,
    activity_type TEXT,
    article_title VARCHAR,
    article_id INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ua.Activity_Date,
        ua.Activity_Type::TEXT,
        a.Title,
        a.Article_ID
    FROM User_Activities ua
    JOIN Articles a ON ua.Article_ID = a.Article_ID
    WHERE ua.User_ID = user_id_param
    AND ua.Activity_Date >= CURRENT_TIMESTAMP - (days_back || ' days')::INTERVAL
    ORDER BY ua.Activity_Date DESC
    LIMIT 50;
END;
$$ LANGUAGE plpgsql;

-- Comments for documentation
COMMENT ON FUNCTION GetArticleLikeCount(INTEGER) IS 'Returns total number of likes for a specific article';
COMMENT ON FUNCTION CheckIfUsernameExists(VARCHAR) IS 'Checks if a username already exists in the system';
COMMENT ON FUNCTION CalculateUserActivityScore(INTEGER) IS 'Calculates weighted activity score for a user';
COMMENT ON FUNCTION GetUserSubscriptionStatus(INTEGER, INTEGER) IS 'Returns subscription status for user-category pair';
COMMENT ON FUNCTION GetCommentCountForArticle(INTEGER) IS 'Returns number of approved comments for an article';
COMMENT ON FUNCTION IsArticleReported(INTEGER) IS 'Checks if article has pending reports';
COMMENT ON FUNCTION GetArticleEngagementScore(INTEGER) IS 'Calculates engagement score for an article';
COMMENT ON FUNCTION GetUserRoleType(INTEGER) IS 'Returns user role type (admin, regular, inactive)';
COMMENT ON FUNCTION GetCategoryArticleCount(INTEGER) IS 'Returns number of published articles in a category';
COMMENT ON FUNCTION ValidateUserCredentials(VARCHAR, VARCHAR) IS 'Validates user login credentials';
