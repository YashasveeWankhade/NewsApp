-- PostgreSQL Database Schema for Newzzz News Application
-- Drop existing tables if they exist (in correct order to handle foreign keys)
DROP TABLE IF EXISTS Article_Categories CASCADE;
DROP TABLE IF EXISTS Reports CASCADE;
DROP TABLE IF EXISTS Subscriptions CASCADE;
DROP TABLE IF EXISTS Views CASCADE;
DROP TABLE IF EXISTS Shares CASCADE;
DROP TABLE IF EXISTS Likes CASCADE;
DROP TABLE IF EXISTS User_Activities CASCADE;
DROP TABLE IF EXISTS Comments CASCADE;
DROP TABLE IF EXISTS Articles CASCADE;
DROP TABLE IF EXISTS News_Sources CASCADE;
DROP TABLE IF EXISTS Subcategory CASCADE;
DROP TABLE IF EXISTS Parent_Category CASCADE;
DROP TABLE IF EXISTS Categories CASCADE;
DROP TABLE IF EXISTS Regular_User CASCADE;
DROP TABLE IF EXISTS Admins CASCADE;
DROP TABLE IF EXISTS Users_Table CASCADE;

-- Create enum types
CREATE TYPE subscription_tier_enum AS ENUM ('free', 'premium', 'enterprise');
CREATE TYPE admin_role_enum AS ENUM ('super_admin', 'content_moderator', 'user_manager');
CREATE TYPE activity_type_enum AS ENUM ('view', 'like', 'share', 'comment');
CREATE TYPE reaction_type_enum AS ENUM ('like', 'dislike', 'love', 'angry', 'sad');
CREATE TYPE platform_type_enum AS ENUM ('facebook', 'twitter', 'linkedin', 'email', 'whatsapp');
CREATE TYPE device_type_enum AS ENUM ('desktop', 'mobile', 'tablet');
CREATE TYPE report_status_enum AS ENUM ('pending', 'resolved', 'rejected');

-- 1. Users_Table (Parent table for ISA hierarchy)
CREATE TABLE Users_Table (
    User_ID SERIAL PRIMARY KEY,
    Username VARCHAR(50) UNIQUE NOT NULL,
    Email VARCHAR(100) UNIQUE NOT NULL,
    Password_Hash VARCHAR(255) NOT NULL,
    Registration_Date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    Last_Login TIMESTAMP,
    Bio TEXT,
    Location VARCHAR(100),
    Is_Active BOOLEAN DEFAULT TRUE,
    Subscription_Tier subscription_tier_enum DEFAULT 'free',
    Created_At TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    Updated_At TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. Admins_Table (ISA: Specialization of Users)
CREATE TABLE Admins (
    Admin_ID INTEGER PRIMARY KEY REFERENCES Users_Table(User_ID) ON DELETE CASCADE,
    Role admin_role_enum NOT NULL DEFAULT 'content_moderator',
    Created_At TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 3. Regular_User_Table (ISA: Specialization of Users)
CREATE TABLE Regular_User (
    User_ID INTEGER PRIMARY KEY REFERENCES Users_Table(User_ID) ON DELETE CASCADE,
    Subscription_tier subscription_tier_enum DEFAULT 'free',
    Created_At TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 4. Categories_Table (Parent table for ISA hierarchy)
CREATE TABLE Categories (
    Category_ID SERIAL PRIMARY KEY,
    Category_Name VARCHAR(100) NOT NULL UNIQUE,
    Description TEXT,
    Created_At TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    Updated_At TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 5. Parent_Category_Table (ISA: Specialization of Categories)
CREATE TABLE Parent_Category (
    Category_ID INTEGER PRIMARY KEY REFERENCES Categories(Category_ID) ON DELETE CASCADE,
    Language_availability VARCHAR(100) DEFAULT 'en',
    Created_At TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 6. Subcategory_Table (ISA: Specialization of Categories)
CREATE TABLE Subcategory (
    Category_ID INTEGER PRIMARY KEY REFERENCES Categories(Category_ID) ON DELETE CASCADE,
    Is_trending BOOLEAN DEFAULT FALSE,
    Parent_Category_ID INTEGER REFERENCES Parent_Category(Category_ID),
    Created_At TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 7. News_Sources_Table
CREATE TABLE News_Sources (
    News_Source_ID SERIAL PRIMARY KEY,
    Name VARCHAR(200) NOT NULL,
    URL VARCHAR(500),
    Description TEXT,
    Reliability_Score DECIMAL(3,2) DEFAULT 0.00 CHECK (Reliability_Score >= 0 AND Reliability_Score <= 10),
    API_Endpoint VARCHAR(500),
    Is_Active BOOLEAN DEFAULT TRUE,
    Created_At TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    Updated_At TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 8. Articles_Table
CREATE TABLE Articles (
    Article_ID SERIAL PRIMARY KEY,
    Title VARCHAR(500) NOT NULL,
    Content TEXT,
    Author VARCHAR(200),
    Excerpt TEXT,
    Publication_Date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    News_Source_ID INTEGER REFERENCES News_Sources(News_Source_ID) ON DELETE SET NULL,
    Views INTEGER DEFAULT 0,
    Likes INTEGER DEFAULT 0,
    Shares INTEGER DEFAULT 0,
    Is_Published BOOLEAN DEFAULT TRUE,
    Image_URL VARCHAR(1000),
    URL VARCHAR(1000),
    Created_At TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    Updated_At TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 9. Comments_Table
CREATE TABLE Comments (
    Comment_ID SERIAL PRIMARY KEY,
    Article_ID INTEGER NOT NULL REFERENCES Articles(Article_ID) ON DELETE CASCADE,
    User_ID INTEGER NOT NULL REFERENCES Users_Table(User_ID) ON DELETE CASCADE,
    Parent_Comment_ID INTEGER REFERENCES Comments(Comment_ID) ON DELETE CASCADE,
    Comment_Text TEXT NOT NULL,
    Comment_Date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    Is_Approved BOOLEAN DEFAULT FALSE,
    Created_At TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    Updated_At TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 10. User_Activities_Table (Parent table for ISA hierarchy)
CREATE TABLE User_Activities (
    Activity_ID SERIAL PRIMARY KEY,
    User_ID INTEGER NOT NULL REFERENCES Users_Table(User_ID) ON DELETE CASCADE,
    Article_ID INTEGER NOT NULL REFERENCES Articles(Article_ID) ON DELETE CASCADE,
    Activity_Type activity_type_enum NOT NULL,
    Activity_Date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    Device_Type device_type_enum DEFAULT 'desktop',
    IP_Address INET,
    Created_At TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 11. Likes_Table (ISA: Specialization of User Activities)
CREATE TABLE Likes (
    Activity_ID INTEGER PRIMARY KEY REFERENCES User_Activities(Activity_ID) ON DELETE CASCADE,
    Article_ID INTEGER NOT NULL REFERENCES Articles(Article_ID) ON DELETE CASCADE,
    Reaction_type reaction_type_enum DEFAULT 'like',
    Created_At TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 12. Shares_Table (ISA: Specialization of User Activities)
CREATE TABLE Shares (
    Activity_ID INTEGER PRIMARY KEY REFERENCES User_Activities(Activity_ID) ON DELETE CASCADE,
    Platform_type platform_type_enum NOT NULL,
    Created_At TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 13. Views_Table (ISA: Specialization of User Activities)
CREATE TABLE Views (
    Activity_ID INTEGER PRIMARY KEY REFERENCES User_Activities(Activity_ID) ON DELETE CASCADE,
    Article_ID INTEGER NOT NULL REFERENCES Articles(Article_ID) ON DELETE CASCADE,
    View_duration INTEGER DEFAULT 0, -- in seconds
    Device_type device_type_enum DEFAULT 'desktop',
    Created_At TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 14. Subscriptions_Table
CREATE TABLE Subscriptions (
    Subscription_ID SERIAL PRIMARY KEY,
    User_ID INTEGER NOT NULL REFERENCES Users_Table(User_ID) ON DELETE CASCADE,
    Category_ID INTEGER NOT NULL REFERENCES Categories(Category_ID) ON DELETE CASCADE,
    Subscription_Date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    Notification_Preferences JSONB DEFAULT '{"email": true, "push": false, "sms": false}'::jsonb,
    Is_Active BOOLEAN DEFAULT TRUE,
    Created_At TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    Updated_At TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(User_ID, Category_ID)
);

-- 15. Reports_Table
CREATE TABLE Reports (
    Report_ID SERIAL PRIMARY KEY,
    Article_ID INTEGER NOT NULL REFERENCES Articles(Article_ID) ON DELETE CASCADE,
    User_ID INTEGER NOT NULL REFERENCES Users_Table(User_ID) ON DELETE CASCADE,
    Admin_ID INTEGER REFERENCES Admins(Admin_ID) ON DELETE SET NULL,
    Report_Reason VARCHAR(500) NOT NULL,
    Report_Date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    Status report_status_enum DEFAULT 'pending',
    Resolution_Notes TEXT,
    Created_At TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    Updated_At TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 16. Article_Categories_Table (Junction Table - Many-to-Many)
CREATE TABLE Article_Categories (
    Article_Category_ID SERIAL PRIMARY KEY,
    Article_ID INTEGER NOT NULL REFERENCES Articles(Article_ID) ON DELETE CASCADE,
    Category_ID INTEGER NOT NULL REFERENCES Categories(Category_ID) ON DELETE CASCADE,
    Created_At TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(Article_ID, Category_ID)
);

-- Create indexes for better performance
CREATE INDEX idx_users_email ON Users_Table(Email);
CREATE INDEX idx_users_username ON Users_Table(Username);
CREATE INDEX idx_users_active ON Users_Table(Is_Active);
CREATE INDEX idx_articles_published ON Articles(Is_Published);
CREATE INDEX idx_articles_publication_date ON Articles(Publication_Date);
CREATE INDEX idx_articles_source ON Articles(News_Source_ID);
CREATE INDEX idx_comments_article ON Comments(Article_ID);
CREATE INDEX idx_comments_user ON Comments(User_ID);
CREATE INDEX idx_comments_approved ON Comments(Is_Approved);
CREATE INDEX idx_user_activities_user ON User_Activities(User_ID);
CREATE INDEX idx_user_activities_article ON User_Activities(Article_ID);
CREATE INDEX idx_user_activities_date ON User_Activities(Activity_Date);
CREATE INDEX idx_subscriptions_user ON Subscriptions(User_ID);
CREATE INDEX idx_subscriptions_category ON Subscriptions(Category_ID);
CREATE INDEX idx_subscriptions_active ON Subscriptions(Is_Active);
CREATE INDEX idx_reports_status ON Reports(Status);
CREATE INDEX idx_article_categories_article ON Article_Categories(Article_ID);
CREATE INDEX idx_article_categories_category ON Article_Categories(Category_ID);

-- Create audit table for admin actions
CREATE TABLE Admin_Audit (
    Audit_ID SERIAL PRIMARY KEY,
    Admin_ID INTEGER REFERENCES Admins(Admin_ID),
    Action VARCHAR(100) NOT NULL,
    Target_Table VARCHAR(50),
    Target_ID INTEGER,
    Old_Values JSONB,
    New_Values JSONB,
    Action_Date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    IP_Address INET
);

COMMENT ON DATABASE postgres IS 'Newzzz News Application Database';
COMMENT ON TABLE Users_Table IS 'Main users table containing all user information';
COMMENT ON TABLE Articles IS 'Articles table containing news articles';
COMMENT ON TABLE Comments IS 'Comments on articles with hierarchical structure';
COMMENT ON TABLE Categories IS 'Categories for organizing articles';
COMMENT ON TABLE User_Activities IS 'User interactions with articles';
COMMENT ON TABLE News_Sources IS 'News sources and their reliability information';
