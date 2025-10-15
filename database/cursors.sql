-- PostgreSQL Cursors for Newzzz News Application
-- Note: PostgreSQL uses functions that return refcursor or table types instead of traditional cursors

-- 1. GetTrendingArticles Cursor
-- Fetches top 10 articles from last 7 days ordered by weighted score
CREATE OR REPLACE FUNCTION GetTrendingArticles(days_back INTEGER DEFAULT 7, limit_count INTEGER DEFAULT 10)
RETURNS REFCURSOR AS $$
DECLARE
    trending_cursor REFCURSOR := 'trending_articles_cursor';
    cutoff_date TIMESTAMP;
BEGIN
    cutoff_date := CURRENT_TIMESTAMP - (days_back || ' days')::INTERVAL;
    
    OPEN trending_cursor FOR
        SELECT 
            a.Article_ID,
            a.Title,
            a.Excerpt,
            a.Publication_Date,
            a.Views,
            a.Likes,
            a.Shares,
            a.Image_URL,
            a.URL,
            ns.Name as Source_Name,
            -- Weighted trending score: views*0.1 + likes*2 + shares*3 + comments*5
            (a.Views * 0.1 + a.Likes * 2.0 + a.Shares * 3.0 + 
             (SELECT COUNT(*) FROM Comments c WHERE c.Article_ID = a.Article_ID AND c.Is_Approved = TRUE) * 5.0) as Trending_Score
        FROM Articles a
        LEFT JOIN News_Sources ns ON a.News_Source_ID = ns.News_Source_ID
        WHERE a.Publication_Date >= cutoff_date
        AND a.Is_Published = TRUE
        ORDER BY Trending_Score DESC
        LIMIT limit_count;
    
    RETURN trending_cursor;
END;
$$ LANGUAGE plpgsql;

-- 2. NotifyUsersOfNewArticleInCategory Cursor
-- Retrieves email addresses of users actively subscribed to a specific category
CREATE OR REPLACE FUNCTION NotifyUsersOfNewArticleInCategory(category_id_param INTEGER)
RETURNS REFCURSOR AS $$
DECLARE
    notify_cursor REFCURSOR := 'notify_users_cursor';
BEGIN
    OPEN notify_cursor FOR
        SELECT DISTINCT
            u.User_ID,
            u.Email,
            u.Username,
            s.Notification_Preferences,
            c.Category_Name
        FROM Users_Table u
        JOIN Subscriptions s ON u.User_ID = s.User_ID
        JOIN Categories c ON s.Category_ID = c.Category_ID
        WHERE s.Category_ID = category_id_param
        AND s.Is_Active = TRUE
        AND u.Is_Active = TRUE
        AND (s.Notification_Preferences->>'email')::boolean = true
        ORDER BY u.Username;
    
    RETURN notify_cursor;
END;
$$ LANGUAGE plpgsql;

-- 3. GetAllPendingReports Cursor
-- Fetches all unresolved reports with article titles and user details for admin dashboard
CREATE OR REPLACE FUNCTION GetAllPendingReports()
RETURNS REFCURSOR AS $$
DECLARE
    reports_cursor REFCURSOR := 'pending_reports_cursor';
BEGIN
    OPEN reports_cursor FOR
        SELECT 
            r.Report_ID,
            r.Report_Reason,
            r.Report_Date,
            r.Status,
            a.Article_ID,
            a.Title as Article_Title,
            a.URL as Article_URL,
            u.User_ID as Reporter_ID,
            u.Username as Reporter_Username,
            u.Email as Reporter_Email,
            admin_u.Username as Assigned_Admin,
            ns.Name as News_Source_Name
        FROM Reports r
        JOIN Articles a ON r.Article_ID = a.Article_ID
        JOIN Users_Table u ON r.User_ID = u.User_ID
        LEFT JOIN Admins adm ON r.Admin_ID = adm.Admin_ID
        LEFT JOIN Users_Table admin_u ON adm.Admin_ID = admin_u.User_ID
        LEFT JOIN News_Sources ns ON a.News_Source_ID = ns.News_Source_ID
        WHERE r.Status = 'pending'
        ORDER BY r.Report_Date ASC;
    
    RETURN reports_cursor;
END;
$$ LANGUAGE plpgsql;

-- 4. GetUserReadingHistory Cursor
-- Retrieves list of articles a specific user has viewed, ordered by most recent
CREATE OR REPLACE FUNCTION GetUserReadingHistory(user_id_param INTEGER, limit_count INTEGER DEFAULT 50)
RETURNS REFCURSOR AS $$
DECLARE
    history_cursor REFCURSOR := 'user_history_cursor';
BEGIN
    OPEN history_cursor FOR
        SELECT DISTINCT
            a.Article_ID,
            a.Title,
            a.Excerpt,
            a.Publication_Date,
            a.Image_URL,
            a.URL,
            ua.Activity_Date as Last_Viewed,
            ns.Name as Source_Name,
            c.Category_Name,
            -- Check if user liked this article
            (SELECT COUNT(*) > 0 FROM User_Activities ua_like 
             WHERE ua_like.User_ID = user_id_param 
             AND ua_like.Article_ID = a.Article_ID 
             AND ua_like.Activity_Type = 'like') as User_Liked,
            -- Check if user shared this article
            (SELECT COUNT(*) > 0 FROM User_Activities ua_share 
             WHERE ua_share.User_ID = user_id_param 
             AND ua_share.Article_ID = a.Article_ID 
             AND ua_share.Activity_Type = 'share') as User_Shared
        FROM User_Activities ua
        JOIN Articles a ON ua.Article_ID = a.Article_ID
        LEFT JOIN News_Sources ns ON a.News_Source_ID = ns.News_Source_ID
        LEFT JOIN Article_Categories ac ON a.Article_ID = ac.Article_ID
        LEFT JOIN Categories c ON ac.Category_ID = c.Category_ID
        WHERE ua.User_ID = user_id_param
        AND ua.Activity_Type = 'view'
        AND a.Is_Published = TRUE
        ORDER BY ua.Activity_Date DESC
        LIMIT limit_count;
    
    RETURN history_cursor;
END;
$$ LANGUAGE plpgsql;

-- 5. GetOrphanedCategories Cursor
-- Fetches categories not linked to any published articles for cleanup
CREATE OR REPLACE FUNCTION GetOrphanedCategories()
RETURNS REFCURSOR AS $$
DECLARE
    orphaned_cursor REFCURSOR := 'orphaned_categories_cursor';
BEGIN
    OPEN orphaned_cursor FOR
        SELECT 
            c.Category_ID,
            c.Category_Name,
            c.Description,
            c.Created_At,
            -- Check if it's a parent category
            (SELECT COUNT(*) FROM Parent_Category pc WHERE pc.Category_ID = c.Category_ID) > 0 as Is_Parent_Category,
            -- Check if it's a subcategory
            (SELECT COUNT(*) FROM Subcategory sc WHERE sc.Category_ID = c.Category_ID) > 0 as Is_Subcategory,
            -- Count total articles ever assigned (including unpublished)
            (SELECT COUNT(*) FROM Article_Categories ac 
             WHERE ac.Category_ID = c.Category_ID) as Total_Articles_Ever,
            -- Count currently published articles
            (SELECT COUNT(*) FROM Article_Categories ac 
             JOIN Articles a ON ac.Article_ID = a.Article_ID 
             WHERE ac.Category_ID = c.Category_ID AND a.Is_Published = TRUE) as Published_Articles
        FROM Categories c
        WHERE c.Category_ID NOT IN (
            SELECT DISTINCT ac.Category_ID 
            FROM Article_Categories ac
            JOIN Articles a ON ac.Article_ID = a.Article_ID
            WHERE a.Is_Published = TRUE
        )
        ORDER BY c.Created_At ASC;
    
    RETURN orphaned_cursor;
END;
$$ LANGUAGE plpgsql;

-- 6. GetCommentThread Cursor
-- For a given Article_ID, fetches entire comment thread with nested replies
CREATE OR REPLACE FUNCTION GetCommentThread(article_id_param INTEGER)
RETURNS REFCURSOR AS $$
DECLARE
    comments_cursor REFCURSOR := 'comment_thread_cursor';
BEGIN
    OPEN comments_cursor FOR
        WITH RECURSIVE comment_tree AS (
            -- Base case: top-level comments (no parent)
            SELECT 
                c.Comment_ID,
                c.Article_ID,
                c.User_ID,
                c.Parent_Comment_ID,
                c.Comment_Text,
                c.Comment_Date,
                c.Is_Approved,
                u.Username,
                u.Email,
                0 as depth_level,
                ARRAY[c.Comment_ID] as path,
                c.Comment_Date as root_date
            FROM Comments c
            JOIN Users_Table u ON c.User_ID = u.User_ID
            WHERE c.Article_ID = article_id_param
            AND c.Parent_Comment_ID IS NULL
            AND c.Is_Approved = TRUE
            
            UNION ALL
            
            -- Recursive case: replies to comments
            SELECT 
                c.Comment_ID,
                c.Article_ID,
                c.User_ID,
                c.Parent_Comment_ID,
                c.Comment_Text,
                c.Comment_Date,
                c.Is_Approved,
                u.Username,
                u.Email,
                ct.depth_level + 1,
                ct.path || c.Comment_ID,
                ct.root_date
            FROM Comments c
            JOIN Users_Table u ON c.User_ID = u.User_ID
            JOIN comment_tree ct ON c.Parent_Comment_ID = ct.Comment_ID
            WHERE c.Is_Approved = TRUE
            AND ct.depth_level < 10  -- Prevent infinite recursion
        )
        SELECT 
            Comment_ID,
            Article_ID,
            User_ID,
            Parent_Comment_ID,
            Comment_Text,
            Comment_Date,
            Is_Approved,
            Username,
            depth_level,
            path,
            -- Create indentation string for display
            REPEAT('  ', depth_level) || '└─ ' as Thread_Indicator
        FROM comment_tree
        ORDER BY root_date ASC, path ASC;
    
    RETURN comments_cursor;
END;
$$ LANGUAGE plpgsql;

-- Additional useful cursors

-- 7. GetTopAuthors Cursor
-- Returns authors with most published articles and engagement
CREATE OR REPLACE FUNCTION GetTopAuthors(limit_count INTEGER DEFAULT 20)
RETURNS REFCURSOR AS $$
DECLARE
    authors_cursor REFCURSOR := 'top_authors_cursor';
BEGIN
    OPEN authors_cursor FOR
        SELECT 
            a.Author,
            COUNT(*) as Article_Count,
            SUM(a.Views) as Total_Views,
            SUM(a.Likes) as Total_Likes,
            SUM(a.Shares) as Total_Shares,
            AVG(a.Views) as Avg_Views_Per_Article,
            AVG(a.Likes) as Avg_Likes_Per_Article,
            MAX(a.Publication_Date) as Latest_Article_Date,
            -- Engagement score
            (SUM(a.Views) * 0.1 + SUM(a.Likes) * 2.0 + SUM(a.Shares) * 3.0) as Engagement_Score
        FROM Articles a
        WHERE a.Is_Published = TRUE
        AND a.Author IS NOT NULL
        AND a.Author != ''
        GROUP BY a.Author
        HAVING COUNT(*) > 0
        ORDER BY Engagement_Score DESC, Article_Count DESC
        LIMIT limit_count;
    
    RETURN authors_cursor;
END;
$$ LANGUAGE plpgsql;

-- 8. GetCategoryPerformance Cursor
-- Returns category performance metrics
CREATE OR REPLACE FUNCTION GetCategoryPerformance()
RETURNS REFCURSOR AS $$
DECLARE
    performance_cursor REFCURSOR := 'category_performance_cursor';
BEGIN
    OPEN performance_cursor FOR
        SELECT 
            c.Category_ID,
            c.Category_Name,
            c.Description,
            COUNT(DISTINCT a.Article_ID) as Article_Count,
            COUNT(DISTINCT s.User_ID) as Subscriber_Count,
            SUM(a.Views) as Total_Views,
            SUM(a.Likes) as Total_Likes,
            SUM(a.Shares) as Total_Shares,
            AVG(a.Views) as Avg_Views_Per_Article,
            -- Engagement rate
            CASE 
                WHEN SUM(a.Views) > 0 
                THEN ROUND((SUM(a.Likes) + SUM(a.Shares)) * 100.0 / SUM(a.Views), 2)
                ELSE 0
            END as Engagement_Rate_Percent,
            -- Activity in last 30 days
            COUNT(CASE WHEN a.Publication_Date >= CURRENT_TIMESTAMP - INTERVAL '30 days' THEN 1 END) as Recent_Articles
        FROM Categories c
        LEFT JOIN Article_Categories ac ON c.Category_ID = ac.Category_ID
        LEFT JOIN Articles a ON ac.Article_ID = a.Article_ID AND a.Is_Published = TRUE
        LEFT JOIN Subscriptions s ON c.Category_ID = s.Category_ID AND s.Is_Active = TRUE
        GROUP BY c.Category_ID, c.Category_Name, c.Description
        ORDER BY Total_Views DESC NULLS LAST, Article_Count DESC;
    
    RETURN performance_cursor;
END;
$$ LANGUAGE plpgsql;

-- Helper function to demonstrate cursor usage
CREATE OR REPLACE FUNCTION DemonstrateCursorUsage()
RETURNS TEXT AS $$
DECLARE
    cur REFCURSOR;
    rec RECORD;
    result_text TEXT := '';
BEGIN
    -- Example: Get trending articles
    SELECT GetTrendingArticles() INTO cur;
    
    result_text := 'TRENDING ARTICLES:' || CHR(10);
    
    LOOP
        FETCH cur INTO rec;
        EXIT WHEN NOT FOUND;
        
        result_text := result_text || '- ' || rec.title || ' (Score: ' || rec.trending_score || ')' || CHR(10);
    END LOOP;
    
    CLOSE cur;
    
    RETURN result_text;
END;
$$ LANGUAGE plpgsql;

-- Cursor management functions
CREATE OR REPLACE FUNCTION GetCursorResults(cursor_name TEXT)
RETURNS SETOF RECORD AS $$
DECLARE
    cur REFCURSOR;
    rec RECORD;
BEGIN
    -- Open cursor by name
    cur := cursor_name::REFCURSOR;
    
    LOOP
        FETCH cur INTO rec;
        EXIT WHEN NOT FOUND;
        RETURN NEXT rec;
    END LOOP;
    
    CLOSE cur;
END;
$$ LANGUAGE plpgsql;

-- Comments for documentation
COMMENT ON FUNCTION GetTrendingArticles(INTEGER, INTEGER) IS 'Returns cursor with trending articles based on engagement metrics';
COMMENT ON FUNCTION NotifyUsersOfNewArticleInCategory(INTEGER) IS 'Returns cursor with users subscribed to a category for notifications';
COMMENT ON FUNCTION GetAllPendingReports() IS 'Returns cursor with all pending reports for admin review';
COMMENT ON FUNCTION GetUserReadingHistory(INTEGER, INTEGER) IS 'Returns cursor with user reading history';
COMMENT ON FUNCTION GetOrphanedCategories() IS 'Returns cursor with categories that have no associated published articles';
COMMENT ON FUNCTION GetCommentThread(INTEGER) IS 'Returns cursor with hierarchical comment thread for an article';
COMMENT ON FUNCTION GetTopAuthors(INTEGER) IS 'Returns cursor with top-performing authors by engagement';
COMMENT ON FUNCTION GetCategoryPerformance() IS 'Returns cursor with category performance metrics';
