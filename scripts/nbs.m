addpath(genpath('/home/ROBARTS/rhaast/Downloads/NBS/NBS1.2'));

global nbs;

io_folder = 'group_comparison';

% Load connectivity matrices and save as mat file
i=1;
matrices = zeros(108,108,36);
for ii=01:36
    tmp = readtable([io_folder,'/subject',num2str(i,'%02.f')]);
    matrices(:,:,ii) = tmp{:,:};
    i = i+1;
end
save([io_folder,'/matrices.mat'],'matrices');

% Load NBS results
load([io_folder,'/nbs_results_etiv.mat']);

% Save test matrix to file
dlmwrite([io_folder,'/ttest_matrix_etiv.txt'],nbs.NBS.test_stat,'delimiter',' ','precision','%d');

% To generate a text file (adj.txt) containing a binary adjacency matrix for
% the first significant network, type the following at the Matlab command prompt:

adj=nbs.NBS.con_mat{1}+nbs.NBS.con_mat{1}';
dlmwrite([io_folder,'/adj_matrix_etiv.txt'],full(adj),'delimiter',' ','precision','%d');

% To print to the screen a list of all connections comprising the first significant
% network as well as their associated test statistics, type the following at the Matlab
% command prompt:

global nbs;
[i,j]=find(nbs.NBS.con_mat{1});

for n=1:length(i)
    i_lab=nbs.NBS.node_label{i(n)};
    j_lab=nbs.NBS.node_label{j(n)};
    stat=nbs.NBS.test_stat(i(n),j(n));
    fprintf('%s to %s. Test stat: %0.2f\n',i_lab,j_lab,stat);
end

% To print to the screen the list of connectivity strengths for a single
% connection across all subjects/observations, type the following at the Matlab command
% prompt:

i=1; %Specify node 1 here
j=2; %Specify node 2 here
global nbs; 
N=nbs.STATS.N; ind_upper=find(triu(ones(N,N),1));

cross_ref=zeros(N,N); cross_ref(ind_upper)=1:length(ind_upper);
cross_ref=cross_ref+cross_ref';
ind=cross_ref(i,j);

fprintf('%0.2f\n',nbs.GLM.y(:,ind));