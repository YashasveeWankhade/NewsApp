import React, { useState, useEffect } from 'react';
import { supabase } from '../config/supabase';
import { Shield, Users, FileText, Flag, CheckCircle } from 'lucide-react';

export const AdminDashboard = () => {
  const [pendingReports, setPendingReports] = useState([]);
  const [pendingComments, setPendingComments] = useState([]);
  const [stats, setStats] = useState({});

  useEffect(() => {
    fetchAdminData();
  }, []);

  const fetchAdminData = async () => {
    // Fetch pending reports
    const { data: reports } = await supabase
      .from('Reports')
      .select('*, Articles(title), Users_Table(username)')
      .eq('status', 'pending');

    setPendingReports(reports || []);

    // Fetch pending comments
    const { data: comments } = await supabase
      .from('Comments')
      .select('*, Articles(title), Users_Table(username)')
      .eq('is_approved', false);

    setPendingComments(comments || []);

    // Fetch stats
    const { data: userCount } = await supabase
      .from('Users_Table')
      .select('user_id', { count: 'exact' });

    const { data: articleCount } = await supabase
      .from('Articles')
      .select('article_id', { count: 'exact' })
      .eq('is_published', true);

    setStats({
      totalUsers: userCount?.length || 0,
      totalArticles: articleCount?.length || 0,
      pendingReports: reports?.length || 0,
      pendingComments: comments?.length || 0
    });
  };

  const approveComment = async (commentId) => {
    await supabase.rpc('approvecomment', { comment_id_param: commentId });
    fetchAdminData();
  };

  const resolveReport = async (reportId, adminId) => {
    await supabase.rpc('resolvereport', { 
      report_id_param: reportId,
      admin_id_param: adminId 
    });
    fetchAdminData();
  };

  return (
    <div className="min-h-screen bg-gray-50 p-8">
      <div className="max-w-7xl mx-auto">
        <h1 className="text-3xl font-bold mb-8 flex items-center">
          <Shield className="w-8 h-8 mr-3 text-purple-600" />
          Admin Dashboard
        </h1>

        {/* Stats Cards */}
        <div className="grid grid-cols-1 md:grid-cols-4 gap-6 mb-8">
          <StatCard 
            icon={<Users />} 
            label="Total Users" 
            value={stats.totalUsers} 
            color="blue"
          />
          <StatCard 
            icon={<FileText />} 
            label="Published Articles" 
            value={stats.totalArticles} 
            color="green"
          />
          <StatCard 
            icon={<Flag />} 
            label="Pending Reports" 
            value={stats.pendingReports} 
            color="red"
          />
          <StatCard 
            icon={<CheckCircle />} 
            label="Pending Comments" 
            value={stats.pendingComments} 
            color="yellow"
          />
        </div>

        {/* Pending Reports */}
        <div className="bg-white rounded-lg shadow-md p-6 mb-8">
          <h2 className="text-xl font-bold mb-4">Pending Reports</h2>
          {pendingReports.map(report => (
            <div key={report.report_id} className="border-b py-4 last:border-0">
              <div className="flex justify-between items-start">
                <div>
                  <p className="font-semibold">{report.Articles?.title}</p>
                  <p className="text-sm text-gray-600 mt-1">
                    Reported by: {report.Users_Table?.username}
                  </p>
                  <p className="text-sm text-gray-800 mt-2">
                    Reason: {report.report_reason}
                  </p>
                </div>
                <button
                  onClick={() => resolveReport(report.report_id, 1)}
                  className="bg-green-600 text-white px-4 py-2 rounded hover:bg-green-700"
                >
                  Resolve
                </button>
              </div>
            </div>
          ))}
        </div>

        {/* Pending Comments */}
        <div className="bg-white rounded-lg shadow-md p-6">
          <h2 className="text-xl font-bold mb-4">Pending Comments</h2>
          {pendingComments.map(comment => (
            <div key={comment.comment_id} className="border-b py-4 last:border-0">
              <div className="flex justify-between items-start">
                <div>
                  <p className="font-semibold">{comment.Articles?.title}</p>
                  <p className="text-sm text-gray-600 mt-1">
                    By: {comment.Users_Table?.username}
                  </p>
                  <p className="text-sm text-gray-800 mt-2 bg-gray-50 p-2 rounded">
                    {comment.comment_text}
                  </p>
                </div>
                <button
                  onClick={() => approveComment(comment.comment_id)}
                  className="bg-blue-600 text-white px-4 py-2 rounded hover:bg-blue-700"
                >
                  Approve
                </button>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
};

const StatCard = ({ icon, label, value, color }) => {
  const colors = {
    blue: 'bg-blue-100 text-blue-600',
    green: 'bg-green-100 text-green-600',
    red: 'bg-red-100 text-red-600',
    yellow: 'bg-yellow-100 text-yellow-600'
  };

  return (
    <div className="bg-white rounded-lg shadow-md p-6">
      <div className={`w-12 h-12 rounded-lg ${colors[color]} flex items-center justify-center mb-4`}>
        {icon}
      </div>
      <p className="text-gray-600 text-sm">{label}</p>
      <p className="text-3xl font-bold text-gray-900">{value}</p>
    </div>
  );
};