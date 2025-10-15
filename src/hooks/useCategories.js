import { useState, useEffect } from 'react';
import { supabase } from '../config/supabase';

export const useCategories = () => {
  const [categories, setCategories] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchCategories();
  }, []);

  const fetchCategories = async () => {
    const { data, error } = await supabase
      .from('Categories')
      .select('*')
      .order('category_name');

    if (!error) {
      setCategories(data);
    }
    setLoading(false);
  };

  const subscribeToCategory = async (userId, categoryId) => {
    const { data, error } = await supabase
      .from('Subscriptions')
      .insert({
        user_id: userId,
        category_id: categoryId,
        is_active: true
      });

    return { data, error };
  };

  return { categories, loading, subscribeToCategory };
};