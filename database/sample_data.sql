-- Sample Data for Newzzz News Application

-- Insert Categories
INSERT INTO Categories (Category_Name, Description) VALUES
('general', 'General news and current events'),
('business', 'Business, finance, and economic news'),
('sports', 'Sports news and updates'),
('science', 'Science, research, and discoveries'),
('health', 'Health, medicine, and wellness'),
('entertainment', 'Entertainment, movies, music, and celebrity news'),
('technology', 'Technology, gadgets, and innovation');

-- Insert Parent Categories (specialization)
INSERT INTO Parent_Category (Category_ID, Language_availability) 
SELECT Category_ID, 'en' FROM Categories WHERE Category_Name IN ('general', 'business', 'technology');

-- Insert Subcategories (specialization)
INSERT INTO Subcategory (Category_ID, Is_trending, Parent_Category_ID)
SELECT 
  s.Category_ID, 
  s.Category_Name IN ('sports', 'entertainment') as Is_trending,
  p.Category_ID
FROM Categories s
CROSS JOIN Categories p
WHERE s.Category_Name IN ('sports', 'science', 'health', 'entertainment')
AND p.Category_Name = 'general'
LIMIT 4;

-- Insert News Sources
INSERT INTO News_Sources (Name, URL, Description, Reliability_Score, Is_Active) VALUES
('TechCrunch', 'https://techcrunch.com', 'Technology and startup news', 8.5, TRUE),
('BBC News', 'https://bbc.com/news', 'British Broadcasting Corporation news', 9.2, TRUE),
('CNN', 'https://cnn.com', 'Cable News Network', 7.8, TRUE),
('Reuters', 'https://reuters.com', 'International news agency', 9.0, TRUE),
('The Guardian', 'https://theguardian.com', 'British daily newspaper', 8.7, TRUE),
('Associated Press', 'https://apnews.com', 'American news agency', 9.1, TRUE),
('ESPN', 'https://espn.com', 'Sports news and entertainment', 8.3, TRUE),
('Wired', 'https://wired.com', 'Technology and science magazine', 8.4, TRUE),
('National Geographic', 'https://nationalgeographic.com', 'Science and nature publication', 9.0, TRUE),
('Variety', 'https://variety.com', 'Entertainment industry news', 7.9, TRUE);

-- Insert Sample Users
INSERT INTO Users_Table (Username, Email, Password_Hash, Bio, Location, Subscription_Tier) VALUES
('admin_user', 'admin@newzzz.com', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewKyNiFK.g.fIjB2', 'System Administrator', 'New York, NY', 'premium'),
('john_doe', 'john@example.com', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewKyNiFK.g.fIjB2', 'Tech enthusiast and news reader', 'San Francisco, CA', 'free'),
('jane_smith', 'jane@example.com', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewKyNiFK.g.fIjB2', 'Business analyst and investor', 'London, UK', 'premium'),
('mike_wilson', 'mike@example.com', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewKyNiFK.g.fIjB2', 'Sports fan and commentator', 'Toronto, Canada', 'free'),
('sarah_brown', 'sarah@example.com', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewKyNiFK.g.fIjB2', 'Science researcher', 'Boston, MA', 'enterprise');

-- Insert Admin (specialization of Users)
INSERT INTO Admins (Admin_ID, Role) VALUES
(1, 'super_admin');

-- Insert Regular Users (specialization of Users)
INSERT INTO Regular_User (User_ID, Subscription_tier) VALUES
(2, 'free'),
(3, 'premium'),
(4, 'free'),
(5, 'enterprise');

-- Insert Sample Articles
INSERT INTO Articles (Title, Content, Author, Excerpt, News_Source_ID, Views, Likes, Shares, Image_URL, URL) VALUES
('Revolutionary AI Breakthrough Changes Everything', 
 'Scientists at MIT have developed a new artificial intelligence system that can understand and generate human-like responses with unprecedented accuracy. This breakthrough represents a significant leap forward in machine learning technology and could revolutionize how we interact with computers.',
 'Dr. Emily Chen', 
 'MIT scientists develop groundbreaking AI system with human-like understanding capabilities.',
 1, 1250, 89, 23,
 'https://images.unsplash.com/photo-1677442136019-21780ecad995?q=80&w=2070',
 'https://example.com/ai-breakthrough'),

('Global Climate Summit Reaches Historic Agreement', 
 'World leaders have reached a unanimous agreement at the Global Climate Summit, committing to ambitious carbon reduction targets and renewable energy investments. The agreement includes binding commitments from all major economies.',
 'Michael Rodriguez', 
 'World leaders unite on climate action with unprecedented global agreement.',
 2, 2100, 156, 67,
 'https://images.unsplash.com/photo-1569163139394-de4e4f43e4e3?q=80&w=2070',
 'https://example.com/climate-summit'),

('Tech Giant Announces Revolutionary Smartphone', 
 'The latest smartphone from TechCorp features breakthrough battery technology that provides 7 days of usage on a single charge, along with advanced AI-powered photography capabilities.',
 'Alex Thompson', 
 'TechCorp unveils smartphone with 7-day battery life and AI photography.',
 1, 3200, 245, 89,
 'https://images.unsplash.com/photo-1511707171634-5f897ff02aa9?q=80&w=2070',
 'https://example.com/new-smartphone'),

('Olympic Games Set New Viewership Records', 
 'The current Olympic Games have broken all previous viewership records, with over 4 billion people worldwide tuning in to watch the competitions. Digital streaming platforms report unprecedented engagement.',
 'Jessica Park', 
 'Olympics shatter viewership records with 4 billion global viewers.',
 7, 1800, 134, 45,
 'https://images.unsplash.com/photo-1461896836934-ffe607ba8211?q=80&w=2070',
 'https://example.com/olympics-viewership'),

('Medical Breakthrough: New Cancer Treatment Shows Promise', 
 'Researchers have developed a new immunotherapy treatment that shows remarkable success rates in treating previously incurable cancers. Clinical trials demonstrate 85% remission rates.',
 'Dr. Robert Kim', 
 'New immunotherapy achieves 85% cancer remission rate in clinical trials.',
 3, 2800, 198, 76,
 'https://images.unsplash.com/photo-1559757148-5c350d0d3c56?q=80&w=2070',
 'https://example.com/cancer-breakthrough'),

('Space Mission Discovers Water on Mars', 
 'NASAs latest Mars rover has confirmed the presence of liquid water beneath the planets surface, bringing us closer to understanding the potential for life on the Red Planet.',
 'Dr. Lisa Wang', 
 'Mars rover confirms liquid water discovery beneath planet surface.',
 6, 4100, 289, 134,
 'https://images.unsplash.com/photo-1446776877081-d282a0f896e2?q=80&w=2070',
 'https://example.com/mars-water'),

('Entertainment Industry Embraces Virtual Reality', 
 'Major movie studios are investing heavily in virtual reality experiences, creating immersive entertainment that puts viewers inside their favorite films and TV shows.',
 'Mark Johnson', 
 'Movie studios revolutionize entertainment with immersive VR experiences.',
 10, 1600, 112, 34,
 'https://images.unsplash.com/photo-1592478411213-6153e4ebc696?q=80&w=2070',
 'https://example.com/vr-entertainment'),

('Global Economy Shows Strong Recovery Signs', 
 'International markets are showing robust growth as economies worldwide recover from recent challenges. GDP growth exceeds expectations in major economies.',
 'David Martinez', 
 'Global markets surge as worldwide economic recovery exceeds projections.',
 4, 2300, 167, 56,
 'https://images.unsplash.com/photo-1590283603385-17ffb3a7f29f?q=80&w=2070',
 'https://example.com/economic-recovery');

-- Associate Articles with Categories
INSERT INTO Article_Categories (Article_ID, Category_ID) VALUES
-- AI Breakthrough - Technology
(1, (SELECT Category_ID FROM Categories WHERE Category_Name = 'technology')),
-- Climate Summit - General
(2, (SELECT Category_ID FROM Categories WHERE Category_Name = 'general')),
-- Smartphone - Technology  
(3, (SELECT Category_ID FROM Categories WHERE Category_Name = 'technology')),
-- Olympics - Sports
(4, (SELECT Category_ID FROM Categories WHERE Category_Name = 'sports')),
-- Cancer Treatment - Health
(5, (SELECT Category_ID FROM Categories WHERE Category_Name = 'health')),
-- Mars Water - Science
(6, (SELECT Category_ID FROM Categories WHERE Category_Name = 'science')),
-- VR Entertainment - Entertainment
(7, (SELECT Category_ID FROM Categories WHERE Category_Name = 'entertainment')),
-- Economic Recovery - Business
(8, (SELECT Category_ID FROM Categories WHERE Category_Name = 'business'));

-- Insert Sample Comments
INSERT INTO Comments (Article_ID, User_ID, Comment_Text, Is_Approved) VALUES
(1, 2, 'This AI breakthrough is absolutely fascinating! The implications for future technology are incredible.', TRUE),
(1, 3, 'I wonder how this will impact job markets in the tech industry.', TRUE),
(1, 4, 'Great article! Looking forward to seeing this technology in action.', TRUE),
(2, 2, 'Finally, world leaders are taking climate change seriously. This gives me hope for the future.', TRUE),
(2, 5, 'The binding commitments are key here. Lets see if countries actually follow through.', TRUE),
(3, 4, '7 days of battery life? That would be a game-changer for heavy phone users like me!', TRUE),
(4, 4, 'These Olympics have been amazing to watch. The digital streaming experience is so much better now.', TRUE),
(5, 5, 'As someone in medical research, this immunotherapy development is truly groundbreaking.', TRUE),
(6, 2, 'Water on Mars! This brings us one step closer to potential colonization.', TRUE),
(6, 3, 'The scientific implications of this discovery are enormous.', TRUE);

-- Insert Sample User Activities
INSERT INTO User_Activities (User_ID, Article_ID, Activity_Type, Device_Type) VALUES
-- Views
(2, 1, 'view', 'desktop'),
(2, 2, 'view', 'mobile'),
(2, 6, 'view', 'desktop'),
(3, 1, 'view', 'tablet'),
(3, 2, 'view', 'desktop'),
(3, 8, 'view', 'mobile'),
(4, 3, 'view', 'mobile'),
(4, 4, 'view', 'desktop'),
(5, 5, 'view', 'desktop'),
(5, 6, 'view', 'tablet'),
-- Likes
(2, 1, 'like', 'desktop'),
(2, 6, 'like', 'desktop'),
(3, 2, 'like', 'desktop'),
(3, 8, 'like', 'mobile'),
(4, 3, 'like', 'mobile'),
(4, 4, 'like', 'desktop'),
(5, 5, 'like', 'desktop'),
-- Shares
(2, 1, 'share', 'desktop'),
(3, 2, 'share', 'desktop'),
(4, 4, 'share', 'desktop'),
(5, 5, 'share', 'desktop');

-- Insert Subscriptions
INSERT INTO Subscriptions (User_ID, Category_ID, Is_Active) VALUES
(2, (SELECT Category_ID FROM Categories WHERE Category_Name = 'technology'), TRUE),
(2, (SELECT Category_ID FROM Categories WHERE Category_Name = 'science'), TRUE),
(3, (SELECT Category_ID FROM Categories WHERE Category_Name = 'business'), TRUE),
(3, (SELECT Category_ID FROM Categories WHERE Category_Name = 'general'), TRUE),
(4, (SELECT Category_ID FROM Categories WHERE Category_Name = 'sports'), TRUE),
(4, (SELECT Category_ID FROM Categories WHERE Category_Name = 'entertainment'), TRUE),
(5, (SELECT Category_ID FROM Categories WHERE Category_Name = 'health'), TRUE),
(5, (SELECT Category_ID FROM Categories WHERE Category_Name = 'science'), TRUE);

-- Insert Sample Reports (for testing admin functionality)
INSERT INTO Reports (Article_ID, User_ID, Report_Reason, Status) VALUES
(7, 4, 'Content seems outdated and potentially misleading', 'pending'),
(3, 5, 'Possible advertising content not clearly marked', 'pending');

-- Update article metrics to match activity data
UPDATE Articles SET 
  Views = (SELECT COUNT(*) FROM User_Activities WHERE Article_ID = Articles.Article_ID AND Activity_Type = 'view'),
  Likes = (SELECT COUNT(*) FROM User_Activities WHERE Article_ID = Articles.Article_ID AND Activity_Type = 'like'),
  Shares = (SELECT COUNT(*) FROM User_Activities WHERE Article_ID = Articles.Article_ID AND Activity_Type = 'share');

-- Create some sample data for specialized activity tables
INSERT INTO Likes (Activity_ID, Article_ID, Reaction_type)
SELECT ua.Activity_ID, ua.Article_ID, 'like'
FROM User_Activities ua
WHERE ua.Activity_Type = 'like';

INSERT INTO Shares (Activity_ID, Platform_type)
SELECT ua.Activity_ID, 'twitter'
FROM User_Activities ua
WHERE ua.Activity_Type = 'share';

INSERT INTO Views (Activity_ID, Article_ID, View_duration, Device_type)
SELECT ua.Activity_ID, ua.Article_ID, 
       CASE ua.Device_Type 
         WHEN 'mobile' THEN 45
         WHEN 'tablet' THEN 120
         ELSE 180
       END,
       ua.Device_Type::device_type_enum
FROM User_Activities ua
WHERE ua.Activity_Type = 'view';

-- Create environment file template
-- Note: This should be created as a separate .env file
COMMENT ON DATABASE postgres IS 'Sample data loaded successfully for Newzzz application';
