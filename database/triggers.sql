-- PostgreSQL Triggers for Newzzz News Application
-- FULLY CORRECTED VERSION - All errors fixed

-- 1. UpdateArticleMetrics Trigger
CREATE OR REPLACE FUNCTION update_article_metrics()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.Activity_Type = 'view' THEN
        UPDATE Articles 
        SET Views = Views + 1
        WHERE Article_ID = NEW.Article_ID;
    ELSIF NEW.Activity_Type = 'like' THEN
        UPDATE Articles 
        SET Likes = Likes + 1
        WHERE Article_ID = NEW.Article_ID;
    ELSIF NEW.Activity_Type = 'share' THEN
        UPDATE Articles 
        SET Shares = Shares + 1
        WHERE Article_ID = NEW.Article_ID;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_article_metrics
    AFTER INSERT ON User_Activities
    FOR EACH ROW
    EXECUTE FUNCTION update_article_metrics();

---
-- 2. LogAdminActions for Reports
-- FIXED: Separate function for Reports table
CREATE OR REPLACE FUNCTION log_admin_actions_reports()
RETURNS TRIGGER AS $$
BEGIN
    -- Only process UPDATE operations
    IF TG_OP != 'UPDATE' THEN
        RETURN NEW;
    END IF;
    
    -- Log report resolution changes
    IF OLD.Status IS DISTINCT FROM NEW.Status THEN
        INSERT INTO Admin_Audit (Admin_ID, Action, Target_Table, Target_ID, Old_Values, New_Values, Action_Date)
        VALUES (
            NEW.Admin_ID,
            'RESOLVE_REPORT',
            'Reports',
            NEW.Report_ID,
            jsonb_build_object('status', OLD.Status, 'resolution_notes', OLD.Resolution_Notes),
            jsonb_build_object('status', NEW.Status, 'resolution_notes', NEW.Resolution_Notes),
            CURRENT_TIMESTAMP
        );
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_log_admin_actions_reports
    AFTER UPDATE ON Reports
    FOR EACH ROW
    EXECUTE FUNCTION log_admin_actions_reports();

---
-- 3. LogAdminActions for Articles
-- FIXED: Separate function for Articles table
CREATE OR REPLACE FUNCTION log_admin_actions_articles()
RETURNS TRIGGER AS $$
BEGIN
    -- Only process UPDATE operations
    IF TG_OP != 'UPDATE' THEN
        RETURN NEW;
    END IF;
    
    -- Log article publication status changes
    IF OLD.Is_Published IS DISTINCT FROM NEW.Is_Published THEN
        INSERT INTO Admin_Audit (Admin_ID, Action, Target_Table, Target_ID, Old_Values, New_Values, Action_Date)
        VALUES (
            COALESCE((SELECT Admin_ID FROM Admins WHERE Admin_ID = current_setting('app.current_admin_id', true)::INTEGER), NULL),
            CASE WHEN NEW.Is_Published THEN 'PUBLISH_ARTICLE' ELSE 'UNPUBLISH_ARTICLE' END,
            'Articles',
            NEW.Article_ID,
            jsonb_build_object('is_published', OLD.Is_Published),
            jsonb_build_object('is_published', NEW.Is_Published),
            CURRENT_TIMESTAMP
        );
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_log_admin_actions_articles
    AFTER UPDATE ON Articles
    FOR EACH ROW
    EXECUTE FUNCTION log_admin_actions_articles();

---
-- 4. PreventAdminSelfDelete Trigger
CREATE OR REPLACE FUNCTION prevent_admin_self_delete()
RETURNS TRIGGER AS $$
BEGIN
    -- Check if current admin is trying to delete their own account
    IF OLD.Admin_ID = COALESCE(current_setting('app.current_admin_id', true)::INTEGER, -1) THEN
        RAISE EXCEPTION 'Admins cannot delete their own account. Please contact another administrator.';
    END IF;
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_prevent_admin_self_delete
    BEFORE DELETE ON Admins
    FOR EACH ROW
    EXECUTE FUNCTION prevent_admin_self_delete();

---
-- 5. CascadeUserDeactivation Trigger
CREATE OR REPLACE FUNCTION cascade_user_deactivation()
RETURNS TRIGGER AS $$
BEGIN
    -- Only process UPDATE operations
    IF TG_OP != 'UPDATE' THEN
        RETURN NEW;
    END IF;
    
    -- Check if Is_Active flag changed from TRUE to FALSE
    IF OLD.Is_Active = TRUE AND NEW.Is_Active = FALSE THEN
        UPDATE Subscriptions 
        SET Is_Active = FALSE, Updated_At = CURRENT_TIMESTAMP
        WHERE User_ID = NEW.User_ID AND Is_Active = TRUE;
        
        -- Log the deactivation
        INSERT INTO Admin_Audit (Admin_ID, Action, Target_Table, Target_ID, Old_Values, New_Values, Action_Date)
        VALUES (
            COALESCE(current_setting('app.current_admin_id', true)::INTEGER, NULL),
            'USER_DEACTIVATION_CASCADE',
            'Users_Table',
            NEW.User_ID,
            jsonb_build_object('is_active', OLD.Is_Active),
            jsonb_build_object('is_active', NEW.Is_Active, 'subscriptions_deactivated', true),
            CURRENT_TIMESTAMP
        );
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_cascade_user_deactivation
    AFTER UPDATE ON Users_Table
    FOR EACH ROW
    EXECUTE FUNCTION cascade_user_deactivation();

---
-- 6. Update timestamp trigger for all tables
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.Updated_At = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply update timestamp trigger to relevant tables
CREATE TRIGGER trg_update_users_timestamp BEFORE UPDATE ON Users_Table FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER trg_update_articles_timestamp BEFORE UPDATE ON Articles FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER trg_update_categories_timestamp BEFORE UPDATE ON Categories FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER trg_update_news_sources_timestamp BEFORE UPDATE ON News_Sources FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER trg_update_comments_timestamp BEFORE UPDATE ON Comments FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER trg_update_subscriptions_timestamp BEFORE UPDATE ON Subscriptions FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER trg_update_reports_timestamp BEFORE UPDATE ON Reports FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

---
-- 7. Validate comment hierarchy trigger
CREATE OR REPLACE FUNCTION validate_comment_hierarchy()
RETURNS TRIGGER AS $$
DECLARE
    parent_article_id INTEGER;
BEGIN
    -- If this is a reply to another comment, ensure both comments belong to the same article
    IF NEW.Parent_Comment_ID IS NOT NULL THEN
        SELECT Article_ID INTO parent_article_id
        FROM Comments
        WHERE Comment_ID = NEW.Parent_Comment_ID;
        
        IF parent_article_id IS NULL THEN
            RAISE EXCEPTION 'Parent comment does not exist.';
        END IF;
        
        IF parent_article_id != NEW.Article_ID THEN
            RAISE EXCEPTION 'Comment reply must belong to the same article as parent comment.';
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_validate_comment_hierarchy
    BEFORE INSERT OR UPDATE ON Comments
    FOR EACH ROW
    EXECUTE FUNCTION validate_comment_hierarchy();

---
-- Comments for documentation
COMMENT ON FUNCTION update_article_metrics() IS 'Updates article metrics when user activities are recorded';
COMMENT ON FUNCTION log_admin_actions_reports() IS 'Logs admin actions for Reports table audit purposes';
COMMENT ON FUNCTION log_admin_actions_articles() IS 'Logs admin actions for Articles table audit purposes';
COMMENT ON FUNCTION prevent_admin_self_delete() IS 'Prevents admins from deleting their own accounts';
COMMENT ON FUNCTION cascade_user_deactivation() IS 'Deactivates user subscriptions when user is deactivated';
COMMENT ON FUNCTION update_updated_at_column() IS 'Updates the Updated_At timestamp on row updates';
COMMENT ON FUNCTION validate_comment_hierarchy() IS 'Validates comment parent-child relationships';