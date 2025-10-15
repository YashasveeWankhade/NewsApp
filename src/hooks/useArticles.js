import { useState, useEffect } from 'react';
import { supabase } from '../config/supabase';

export const useArticles = (categoryId = null) => {
  const [articles, setArticles] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    fetchArticles();
  }, [categoryId]);

  const fetchArticles = async () => {
    try {
      let query = supabase
        .from('Articles')
        .select(`
          *,
          News_Sources (name),
          Article_Categories (
            Categories (category_name)
          )
        `)
        .eq('is_published', true)
        .order('publication_date', { ascending: false });

      if (categoryId) {
        query = query.eq('Article_Categories.category_id', categoryId);
      }

      const { data, error } = await query;

      if (error) throw error;
      setArticles(data);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  const recordView = async (articleId, userId) => {
    await supabase.from('User_Activities').insert({
      user_id: userId,
      article_id: articleId,
      activity_type: 'view',
      device_type: 'desktop'
    });
  };

  const likeArticle = async (articleId, userId) => {
    const { data, error } = await supabase
      .from('User_Activities')
      .insert({
        user_id: userId,
        article_id: articleId,
        activity_type: 'like',
        device_type: 'desktop'
      })
      .select()
      .single();

    if (!error && data) {
      // Insert into Likes table
      await supabase.from('Likes').insert({
        activity_id: data.activity_id,
        article_id: articleId,
        reaction_type: 'like'
      });
    }

    return { data, error };
  };

  const shareArticle = async (articleId, userId, platform) => {
    const { data, error } = await supabase
      .from('User_Activities')
      .insert({
        user_id: userId,
        article_id: articleId,
        activity_type: 'share',
        device_type: 'desktop'
      })
      .select()
      .single();

    if (!error && data) {
      await supabase.from('Shares').insert({
        activity_id: data.activity_id,
        platform_type: platform || 'twitter'
      });
    }

    return { data, error };
  };

  return { 
    articles, 
    loading, 
    error, 
    recordView, 
    likeArticle, 
    shareArticle,
    refetch: fetchArticles 
  };
};