import React, { useState, useEffect } from 'react';
import { supabase } from '../config/supabase';
import { MessageSquare, Send } from 'lucide-react';

export const CommentSection = ({ articleId, userId }) => {
  const [comments, setComments] = useState([]);
  const [newComment, setNewComment] = useState('');
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    fetchComments();
  }, [articleId]);

  const fetchComments = async () => {
    const { data, error } = await supabase
      .from('Comments')
      .select(`
        *,
        Users_Table (username)
      `)
      .eq('article_id', articleId)
      .eq('is_approved', true)
      .order('comment_date', { ascending: false });

    if (!error) setComments(data);
  };

  const submitComment = async (e) => {
    e.preventDefault();
    if (!newComment.trim() || !userId) return;

    setLoading(true);
    const { error } = await supabase
      .from('Comments')
      .insert({
        article_id: articleId,
        user_id: userId,
        comment_text: newComment,
        is_approved: false // Requires admin approval
      });

    if (!error) {
      setNewComment('');
      alert('Comment submitted for approval!');
    }
    setLoading(false);
  };

  return (
    <div className="mt-8">
      <h3 className="text-xl font-bold mb-4 flex items-center">
        <MessageSquare className="w-5 h-5 mr-2" />
        Comments ({comments.length})
      </h3>

      {userId && (
        <form onSubmit={submitComment} className="mb-6">
          <textarea
            value={newComment}
            onChange={(e) => setNewComment(e.target.value)}
            placeholder="Share your thoughts..."
            className="w-full p-3 border rounded-lg focus:ring-2 focus:ring-purple-500"
            rows="3"
          />
          <button
            type="submit"
            disabled={loading}
            className="mt-2 bg-purple-600 text-white px-4 py-2 rounded-lg flex items-center space-x-2 hover:bg-purple-700"
          >
            <Send className="w-4 h-4" />
            <span>{loading ? 'Submitting...' : 'Post Comment'}</span>
          </button>
        </form>
      )}

      <div className="space-y-4">
        {comments.map(comment => (
          <div key={comment.comment_id} className="bg-gray-50 p-4 rounded-lg">
            <div className="flex justify-between items-start mb-2">
              <span className="font-semibold text-gray-900">
                {comment.Users_Table?.username || 'Anonymous'}
              </span>
              <span className="text-sm text-gray-500">
                {new Date(comment.comment_date).toLocaleDateString()}
              </span>
            </div>
            <p className="text-gray-700">{comment.comment_text}</p>
          </div>
        ))}
      </div>
    </div>
  );
};