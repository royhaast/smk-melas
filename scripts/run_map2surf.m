function run_map2surf(in_file,out_file,method)

rehash toolboxcache    
addpath('./spm12','./spm12/toolbox/suit');

if strcmp(method,'mode')
    disp('Using @mode')
    C.cdata=suit_map2surf(in_file,'stats',@mode);
else
    disp('Using @minORmax')
    C.cdata=suit_map2surf(in_file,'stats',@minORmax);
end

C=gifti(C);

save(C,out_file);

end
