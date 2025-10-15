// Complete App.jsx with Supabase Integration
// src/App.jsx

import React, { useState, useEffect } from 'react';
import { createClient } from '@supabase/supabase-js';
import { 
  Search, Menu, X, TrendingUp, Home, BookmarkPlus, User, 
  Settings, LogOut, Heart, Share2, Eye, MessageSquare, 
  Filter, Bell, Send, Flag, Shield 
} from 'lucide-react';

// Initialize Supabase Client
const supabaseUrl = import.meta.env.VITE_SUPABASE_URL || 'YOUR_SUPABASE_URL';
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY || 'YOUR_SUPABASE_KEY';
const supabase = createClient(supabaseUrl, supabaseAnonKey);

const App = () => {
  // State Management
  const [currentUser, setCurrentUser] = useState(null);
  const [currentView, setCurrentView] = useState('home');
  const [articles, setArticles] = useState([]);
  const [categories, setCategories] = useState([]);
  const [selectedCategory, setSelectedCategory] = useState('all');
  const [searchQuery, setSearchQuery] = useState('');
  const [menuOpen, setMenuOpen] = useState(false);
  const [showAuthModal, setShowAuthModal] = useState(false);
  const [authMode, setAuthMode] = useState('login');
  const [loading, setLoading] = useState(true);
  const [selectedArticle, setSelectedArticle] = useState(null);

  // Auth form state
  const [authForm, setAuthForm] = useState({
    email: '',
    password: '',
    username: ''
  });

  // Initialize app - Check auth and fetch data
  useEffect(() => {
    initializeApp();
  }, []);

  const initializeApp = async () => {
    // Check current session
    const { data: { session } } = await supabase.auth.getSession();
    if (session?.user) {
      await fetchUserData(session.user.id);
    }

    // Fetch initial data
    await Promise.all([
      fetchArticles(),
      fetchCategories()
    ]);

    setLoading(false);

    // Listen for auth changes
    supabase.auth.onAuthStateChange(async (event, session) => {
      if (session?.user) {
        await fetchUserData(session.user.id);
      } else {
        setCurrentUser(null);
      }
    });
  };

  // Fetch user data from Users_Table
  const fetchUserData = async (userId) => {
    const { data, error } = await supabase
      .from('Users_Table')
      .select('*')
      .eq('user_id', userId)
      .single();

    if (!error && data) {
      setCurrentUser(data);
    }
  };

  // Fetch articles with joins
  const fetchArticles = async (categoryFilter = null) => {
    let query = supabase
      .from('Articles')
      .select(`
        *,
        News_Sources (name, reliability_score),
        Article_Categories!inner (
          Categories (category_id, category_name)
        )
      `)
      .eq('is_published', true)
      .order('publication_date', { ascending: false })
      .limit(50);

    if (categoryFilter && categoryFilter !== 'all') {
      query = query.eq('Article_Categories.Categories.category_name', categoryFilter);
    }

    const { data, error } = await query;

    if (!error && data) {
      // Transform data to flatten structure
      const transformedArticles = data.map(article => ({
        ...article,
        source_name: article.News_Sources?.name,
        category_name: article.Article_Categories?.[0]?.Categories?.category_name || 'General'
      }));
      setArticles(transformedArticles);
    }
  };

  // Fetch categories with article counts
  const fetchCategories = async () => {
    const { data, error } = await supabase
      .from('Categories')
      .select('category_id, category_name')
      .order('category_name');

    if (!error && data) {
      // Get article counts for each category
      const categoriesWithCounts = await Promise.all(
        data.map(async (cat) => {
          const { count } = await supabase
            .from('Article_Categories')
            .select('*', { count: 'exact', head: true })
            .eq('category_id', cat.category_id);

          return { ...cat, article_count: count || 0 };
        })
      );
      setCategories(categoriesWithCounts);
    }
  };

  // Fetch trending articles using RPC
  const fetchTrendingArticles = async () => {
    const { data, error } = await supabase
      .rpc('gettrendingarticles', { days_back: 7, limit_count: 10 });

    if (!error && data) {
      setArticles(data);
    }
  };

  // Authentication functions
  const handleSignUp = async (e) => {
    e.preventDefault();
    const { data, error } = await supabase.auth.signUp({
      email: authForm.email,
      password: authForm.password,
      options: {
        data: { username: authForm.username }
      }
    });

    if (!error) {
      // Insert user into Users_Table
      await supabase.from('Users_Table').insert({
        user_id: data.user.id,
        username: authForm.username,
        email: authForm.email,
        password_hash: 'managed_by_supabase_auth',
        is_active: true,
        subscription_tier: 'free'
      });

      // Insert into Regular_User table
      await supabase.from('Regular_User').insert({
        user_id: data.user.id,
        subscription_tier: 'free'
      });

      alert('Account created! Please check your email to verify.');
      setShowAuthModal(false);
    } else {
      alert('Error: ' + error.message);
    }
  };

  const handleSignIn = async (e) => {
    e.preventDefault();
    const { error } = await supabase.auth.signInWithPassword({
      email: authForm.email,
      password: authForm.password
    });

    if (!error) {
      setShowAuthModal(false);
    } else {
      alert('Error: ' + error.message);
    }
  };

  const handleSignOut = async () => {
    await supabase.auth.signOut();
    setCurrentUser(null);
  };

  // Article interaction functions
  const handleArticleView = async (articleId) => {
    setSelectedArticle(articles.find(a => a.article_id === articleId));

    if (currentUser) {
      // Record view in User_Activities
      const { data: activityData } = await supabase
        .from('User_Activities')
        .insert({
          user_id: currentUser.user_id,
          article_id: articleId,
          activity_type: 'view',
          device_type: 'desktop'
        })
        .select()
        .single();

      // Record in Views table
      if (activityData) {
        await supabase.from('Views').insert({
          activity_id: activityData.activity_id,
          article_id: articleId,
          view_duration: 0,
          device_type: 'desktop'
        });
      }
    }
  };

  const handleLike = async (articleId) => {
    if (!currentUser) {
      alert('Please login to like articles');
      return;
    }

    // Insert into User_Activities
    const { data: activityData, error } = await supabase
      .from('User_Activities')
      .insert({
        user_id: currentUser.user_id,
        article_id: articleId,
        activity_type: 'like',
        device_type: 'desktop'
      })
      .select()
      .single();

    if (!error && activityData) {
      // Insert into Likes table
      await supabase.from('Likes').insert({
        activity_id: activityData.activity_id,
        article_id: articleId,
        reaction_type: 'like'
      });

      // Refresh articles to get updated counts
      await fetchArticles(selectedCategory === 'all' ? null : selectedCategory);
    }
  };

  const handleShare = async (articleId, platform = 'twitter') => {
    if (!currentUser) {
      alert('Please login to share articles');
      return;
    }

    const { data: activityData, error } = await supabase
      .from('User_Activities')
      .insert({
        user_id: currentUser.user_id,
        article_id: articleId,
        activity_type: 'share',
        device_type: 'desktop'
      })
      .select()
      .single();

    if (!error && activityData) {
      await supabase.from('Shares').insert({
        activity_id: activityData.activity_id,
        platform_type: platform
      });

      alert('Article shared!');
      await fetchArticles(selectedCategory === 'all' ? null : selectedCategory);
    }
  };

  // Subscribe to category
  const handleCategorySubscribe = async (categoryId) => {
    if (!currentUser) {
      alert('Please login to subscribe');
      return;
    }

    const { error } = await supabase
      .from('Subscriptions')
      .insert({
        user_id: currentUser.user_id,
        category_id: categoryId,
        is_active: true,
        notification_preferences: { email: true, push: false, sms: false }
      });

    if (!error) {
      alert('Subscribed to category!');
    } else if (error.code === '23505') {
      alert('Already subscribed to this category');
    }
  };

  // Search articles
  const handleSearch = async (query) => {
    if (!query.trim()) {
      fetchArticles(selectedCategory === 'all' ? null : selectedCategory);
      return;
    }

    const { data, error } = await supabase
      .from('Articles')
      .select(`
        *,
        News_Sources (name),
        Article_Categories (Categories (category_name))
      `)
      .or(`title.ilike.%${query}%,excerpt.ilike.%${query}%,content.ilike.%${query}%`)
      .eq('is_published', true)
      .limit(50);

    if (!error && data) {
      const transformedArticles = data.map(article => ({
        ...article,
        source_name: article.News_Sources?.name,
        category_name: article.Article_Categories?.[0]?.Categories?.category_name || 'General'
      }));
      setArticles(transformedArticles);
    }
  };

  // Category filter handler
  const handleCategoryChange = (categoryName) => {
    setSelectedCategory(categoryName);
    fetchArticles(categoryName === 'all' ? null : categoryName);
  };

  // Components
  const ArticleCard = ({ article }) => (
    <div className="bg-white rounded-lg shadow-md overflow-hidden hover:shadow-xl transition-shadow duration-300">
      {article.image_url && (
        <img 
          src={article.image_url} 
          alt={article.title}
          className="w-full h-48 object-cover cursor-pointer"
          onClick={() => handleArticleView(article.article_id)}
        />
      )}
      <div className="p-4">
        <div className="flex items-center justify-between mb-2">
          <span className="text-xs font-semibold text-purple-600 bg-purple-100 px-2 py-1 rounded">
            {article.category_name}
          </span>
          <span className="text-xs text-gray-500">
            {new Date(article.publication_date).toLocaleDateString()}
          </span>
        </div>
        
        <h3 
          className="text-lg font-bold text-gray-900 mb-2 line-clamp-2 cursor-pointer hover:text-purple-600"
          onClick={() => handleArticleView(article.article_id)}
        >
          {article.title}
        </h3>
        
        <p className="text-sm text-gray-600 mb-3 line-clamp-2">
          {article.excerpt}
        </p>
        
        <div className="flex items-center justify-between text-sm text-gray-500 mb-3">
          <span className="font-medium">{article.author}</span>
          {article.source_name && (
            <span className="text-xs">{article.source_name}</span>
          )}
        </div>
        
        <div className="flex items-center justify-between pt-3 border-t border-gray-200">
          <div className="flex space-x-4">
            <button className="flex items-center space-x-1 text-gray-600">
              <Eye className="w-4 h-4" />
              <span className="text-xs">{article.views || 0}</span>
            </button>
            
            <button 
              onClick={() => handleLike(article.article_id)}
              className="flex items-center space-x-1 text-gray-600 hover:text-red-600"
            >
              <Heart className="w-4 h-4" />
              <span className="text-xs">{article.likes || 0}</span>
            </button>
            
            <button 
              onClick={() => handleShare(article.article_id)}
              className="flex items-center space-x-1 text-gray-600 hover:text-green-600"
            >
              <Share2 className="w-4 h-4" />
              <span className="text-xs">{article.shares || 0}</span>
            </button>
          </div>
          
          <button 
            onClick={() => handleArticleView(article.article_id)}
            className="text-purple-600 font-semibold text-sm hover:text-purple-800"
          >
            Read More →
          </button>
        </div>
      </div>
    </div>
  );

  const AuthModal = () => (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
      <div className="bg-white rounded-lg max-w-md w-full p-6">
        <div className="flex justify-between items-center mb-6">
          <h2 className="text-2xl font-bold text-gray-900">
            {authMode === 'login' ? 'Login' : 'Sign Up'}
          </h2>
          <button onClick={() => setShowAuthModal(false)}>
            <X className="w-6 h-6 text-gray-600" />
          </button>
        </div>
        
        <form onSubmit={authMode === 'login' ? handleSignIn : handleSignUp} className="space-y-4">
          {authMode === 'signup' && (
            <input
              type="text"
              placeholder="Username"
              value={authForm.username}
              onChange={(e) => setAuthForm({...authForm, username: e.target.value})}
              required
              className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-transparent"
            />
          )}
          
          <input
            type="email"
            placeholder="Email"
            value={authForm.email}
            onChange={(e) => setAuthForm({...authForm, email: e.target.value})}
            required
            className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-transparent"
          />
          
          <input
            type="password"
            placeholder="Password"
            value={authForm.password}
            onChange={(e) => setAuthForm({...authForm, password: e.target.value})}
            required
            minLength={6}
            className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-transparent"
          />
          
          <button 
            type="submit"
            className="w-full bg-purple-600 text-white py-2 rounded-lg font-semibold hover:bg-purple-700 transition-colors"
          >
            {authMode === 'login' ? 'Login' : 'Sign Up'}
          </button>
          
          <p className="text-center text-sm text-gray-600">
            {authMode === 'login' ? "Don't have an account? " : "Already have an account? "}
            <button 
              type="button"
              onClick={() => setAuthMode(authMode === 'login' ? 'signup' : 'login')}
              className="text-purple-600 font-semibold hover:text-purple-800"
            >
              {authMode === 'login' ? 'Sign Up' : 'Login'}
            </button>
          </p>
        </form>
      </div>
    </div>
  );

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gray-50">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-purple-600 mx-auto mb-4"></div>
          <p className="text-gray-600">Loading Newzzz...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Header */}
      <header className="bg-white shadow-md sticky top-0 z-40">
        <div className="max-w-7xl mx-auto px-4 py-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center space-x-4">
              <button 
                onClick={() => setMenuOpen(!menuOpen)}
                className="lg:hidden text-gray-600"
              >
                {menuOpen ? <X className="w-6 h-6" /> : <Menu className="w-6 h-6" />}
              </button>
              
              <h1 className="text-2xl font-bold text-purple-600 cursor-pointer" onClick={() => setCurrentView('home')}>
                Newzzz
              </h1>
            </div>
            
            <div className="hidden md:flex flex-1 max-w-xl mx-8">
              <div className="relative w-full">
                <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400 w-5 h-5" />
                <input
                  type="text"
                  placeholder="Search articles..."
                  value={searchQuery}
                  onChange={(e) => {
                    setSearchQuery(e.target.value);
                    if (e.target.value.length > 2) {
                      handleSearch(e.target.value);
                    } else if (e.target.value.length === 0) {
                      fetchArticles(selectedCategory === 'all' ? null : selectedCategory);
                    }
                  }}
                  className="w-full pl-10 pr-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-transparent"
                />
              </div>
            </div>
            
            <div className="flex items-center space-x-4">
              {currentUser ? (
                <>
                  <button className="relative text-gray-600 hover:text-purple-600">
                    <Bell className="w-6 h-6" />
                    <span className="absolute -top-1 -right-1 bg-red-500 text-white text-xs rounded-full w-4 h-4 flex items-center justify-center">
                      3
                    </span>
                  </button>
                  <div className="relative group">
                    <button className="flex items-center space-x-2 text-gray-700 hover:text-purple-600">
                      <User className="w-6 h-6" />
                      <span className="hidden md:block text-sm font-medium">
                        {currentUser.username}
                      </span>
                    </button>
                    <div className="absolute right-0 mt-2 w-48 bg-white rounded-lg shadow-lg py-2 hidden group-hover:block">
                      <button className="w-full text-left px-4 py-2 hover:bg-gray-100 flex items-center space-x-2">
                        <Settings className="w-4 h-4" />
                        <span>Settings</span>
                      </button>
                      <button 
                        onClick={handleSignOut}
                        className="w-full text-left px-4 py-2 hover:bg-gray-100 flex items-center space-x-2 text-red-600"
                      >
                        <LogOut className="w-4 h-4" />
                        <span>Logout</span>
                      </button>
                    </div>
                  </div>
                </>
              ) : (
                <button 
                  onClick={() => setShowAuthModal(true)}
                  className="bg-purple-600 text-white px-4 py-2 rounded-lg font-semibold hover:bg-purple-700 transition-colors"
                >
                  Login
                </button>
              )}
            </div>
          </div>
          
          {/* Mobile Search */}
          <div className="md:hidden mt-4">
            <div className="relative">
              <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400 w-5 h-5" />
              <input
                type="text"
                placeholder="Search articles..."
                value={searchQuery}
                onChange={(e) => {
                  setSearchQuery(e.target.value);
                  if (e.target.value.length > 2) {
                    handleSearch(e.target.value);
                  }
                }}
                className="w-full pl-10 pr-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-transparent"
              />
            </div>
          </div>
        </div>
      </header>

      {/* Main Content */}
      <div className="max-w-7xl mx-auto px-4 py-8">
        <div className="flex flex-col lg:flex-row gap-8">
          {/* Sidebar */}
          <aside className={`lg:w-64 ${menuOpen ? 'block' : 'hidden lg:block'}`}>
            <div className="bg-white rounded-lg shadow-md p-4 sticky top-24">
              <nav className="space-y-2">
                <button 
                  onClick={() => {
                    setCurrentView('home');
                    fetchArticles(selectedCategory === 'all' ? null : selectedCategory);
                  }}
                  className={`w-full flex items-center space-x-3 px-4 py-3 rounded-lg transition-colors ${
                    currentView === 'home' 
                      ? 'bg-purple-50 text-purple-600 font-semibold' 
                      : 'text-gray-700 hover:bg-purple-50 hover:text-purple-600'
                  }`}
                >
                  <Home className="w-5 h-5" />
                  <span className="font-medium">Home</span>
                </button>
                
                <button 
                  onClick={() => {
                    setCurrentView('trending');
                    fetchTrendingArticles();
                  }}
                  className={`w-full flex items-center space-x-3 px-4 py-3 rounded-lg transition-colors ${
                    currentView === 'trending' 
                      ? 'bg-purple-50 text-purple-600 font-semibold' 
                      : 'text-gray-700 hover:bg-purple-50 hover:text-purple-600'
                  }`}
                >
                  <TrendingUp className="w-5 h-5" />
                  <span className="font-medium">Trending</span>
                </button>
                
                <button className="w-full flex items-center space-x-3 px-4 py-3 text-gray-700 hover:bg-purple-50 hover:text-purple-600 rounded-lg transition-colors">
                  <BookmarkPlus className="w-5 h-5" />
                  <span className="font-medium">Saved</span>
                </button>
              </nav>
              
              <div className="mt-6 pt-6 border-t border-gray-200">
                <h3 className="text-sm font-semibold text-gray-900 mb-3">Categories</h3>
                <div className="space-y-1">
                  <button
                    onClick={() => handleCategoryChange('all')}
                    className={`w-full text-left px-3 py-2 rounded-lg text-sm transition-colors ${
                      selectedCategory === 'all' 
                        ? 'bg-purple-50 text-purple-600 font-medium' 
                        : 'text-gray-700 hover:bg-gray-50'
                    }`}
                  >
                    All Articles
                  </button>
                  {categories.map(cat => (
                    <div key={cat.category_id} className="group">
                      <button
                        onClick={() => handleCategoryChange(cat.category_name)}
                        className={`w-full text-left px-3 py-2 rounded-lg text-sm transition-colors ${
                          selectedCategory === cat.category_name 
                            ? 'bg-purple-50 text-purple-600 font-medium' 
                            : 'text-gray-700 hover:bg-gray-50'
                        }`}
                      >
                        <div className="flex items-center justify-between">
                          <span>{cat.category_name}</span>
                          <div className="flex items-center space-x-2">
                            <span className="text-gray-400 text-xs">{cat.article_count}</span>
                            {currentUser && (
                              <button
                                onClick={(e) => {
                                  e.stopPropagation();
                                  handleCategorySubscribe(cat.category_id);
                                }}
                                className="opacity-0 group-hover:opacity-100 text-purple-600 hover:text-purple-800"
                                title="Subscribe"
                              >
                                <Bell className="w-3 h-3" />
                              </button>
                            )}
                          </div>
                        </div>
                      </button>
                    </div>
                  ))}
                </div>
              </div>
            </div>
          </aside>

          {/* Articles Grid */}
          <main className="flex-1">
            <div className="flex items-center justify-between mb-6">
              <h2 className="text-2xl font-bold text-gray-900">
                {currentView === 'trending' ? 'Trending Now' : 
                 selectedCategory === 'all' ? 'Latest Articles' : selectedCategory}
              </h2>
              <div className="flex items-center space-x-2">
                <span className="text-sm text-gray-600">{articles.length} articles</span>
                <button className="flex items-center space-x-2 text-gray-600 hover:text-purple-600">
                  <Filter className="w-5 h-5" />
                </button>
              </div>
            </div>
            
            <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-6">
              {articles.map(article => (
                <ArticleCard key={article.article_id} article={article} />
              ))}
            </div>
            
            {articles.length === 0 && (
              <div className="text-center py-12">
                <p className="text-gray-500 text-lg">No articles found</p>
                <p className="text-gray-400 text-sm mt-2">Try adjusting your search or filters</p>
              </div>
            )}
          </main>
        </div>
      </div>

      {/* Auth Modal */}
      {showAuthModal && <AuthModal />}

      {/* Article Detail Modal */}
      {selectedArticle && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4 overflow-y-auto">
          <div className="bg-white rounded-lg max-w-4xl w-full my-8">
            <div className="p-6">
              <div className="flex justify-between items-start mb-4">
                <span className="text-sm font-semibold text-purple-600 bg-purple-100 px-3 py-1 rounded">
                  {selectedArticle.category_name}
                </span>
                <button onClick={() => setSelectedArticle(null)}>
                  <X className="w-6 h-6 text-gray-600 hover:text-gray-900" />
                </button>
              </div>
              
              <h1 className="text-3xl font-bold text-gray-900 mb-4">
                {selectedArticle.title}
              </h1>
              
              <div className="flex items-center justify-between text-sm text-gray-600 mb-6 pb-6 border-b">
                <div>
                  <p className="font-medium">{selectedArticle.author}</p>
                  <p className="text-xs">{selectedArticle.source_name}</p>
                </div>
                <p>{new Date(selectedArticle.publication_date).toLocaleDateString()}</p>
              </div>
              
              {selectedArticle.image_url && (
                <img 
                  src={selectedArticle.image_url} 
                  alt={selectedArticle.title}
                  className="w-full h-96 object-cover rounded-lg mb-6"
                />
              )}
              
              <div className="prose max-w-none mb-6">
                <p className="text-lg text-gray-700 leading-relaxed">
                  {selectedArticle.content || selectedArticle.excerpt}
                </p>
              </div>
              
              <div className="flex items-center space-x-6 py-4 border-t border-b">
                <button 
                  onClick={() => handleLike(selectedArticle.article_id)}
                  className="flex items-center space-x-2 text-gray-600 hover:text-red-600"
                >
                  <Heart className="w-5 h-5" />
                  <span>{selectedArticle.likes || 0} Likes</span>
                </button>
                
                <button 
                  onClick={() => handleShare(selectedArticle.article_id)}
                  className="flex items-center space-x-2 text-gray-600 hover:text-green-600"
                >
                  <Share2 className="w-5 h-5" />
                  <span>{selectedArticle.shares || 0} Shares</span>
                </button>
                
                <div className="flex items-center space-x-2 text-gray-600">
                  <Eye className="w-5 h-5" />
                  <span>{selectedArticle.views || 0} Views</span>
                </div>
              </div>
              
              {selectedArticle.url && (
                <div className="mt-6">
                  <a 
                    href={selectedArticle.url} 
                    target="_blank" 
                    rel="noopener noreferrer"
                    className="text-purple-600 hover:text-purple-800 font-semibold"
                  >
                    Read full article on {selectedArticle.source_name} →
                  </a>
                </div>
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default App;