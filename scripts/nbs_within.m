addpath(genpath('/home/ROBARTS/rhaast/Downloads/NBS/NBS1.2'));

global nbs;

io_folder = 'across_patients';

% Load connectivity matrices and save as mat file
i=1;
matrices = zeros(108,108,21);
for ii=01:21
    tmp = readtable([io_folder,'/subject',num2str(i,'%02.f')]);
    matrices(:,:,ii) = tmp{:,:};
    i = i+1;
end
save([io_folder,'/matrices.mat'],'matrices');

% Load NBS results
load([io_folder,'/nbs_results.mat']);

% Save test matrix to file
dlmwrite([io_folder,'/ttest_matrix.txt'],nbs.NBS.test_stat,'delimiter',' ','precision','%d');

% To generate a text file (adj.txt) containing a binary adjacency matrix for
% the first significant network, type the following at the Matlab command prompt:

adj=nbs.NBS.con_mat{1}+nbs.NBS.con_mat{1}';
dlmwrite([io_folder,'/adj_matrix.txt'],full(adj),'delimiter',' ','precision','%d');
