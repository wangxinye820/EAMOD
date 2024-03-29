clear all;
clc;
res_all=[];

for data_num =1:9 
    get_dnames;
    dnames = [dname];
    tot_data = load([dnames '.mat']);
    
    data_only = tot_data.data(:,1:end-1);
    data_labels = tot_data.data(:,end);
    data_label = data_labels;
    classes_all = unique(data_label);
    
    for first_class=1:length(classes_all)
        tic
        if (data_num==1 && first_class~=1)
            continue;
        end
        
        count=0;
        res.dname=[dname num2str(first_class)];
        pos_class = classes_all(first_class);
        data_label(data_labels==pos_class) = 1;
        data_label(data_labels~=pos_class) = 2;
        target_data = data_only(data_label==1,:);
        target_data = cat(2, target_data, ones(size(target_data,1),1));
        outlier_data = data_only(data_label==2,:);
        outlier_data = cat(2, outlier_data, ones(size(outlier_data,1),1).*2);
        tot_run = 10;  tot_fold=10;
        %%%%%%%%%%%%%%%%%%%%%%       
%         load([dname '5' num2str(first_class) 'pos']);
%         ind_pos_all = fold_run_pos;
%         load([dname '5' num2str(first_class) 'neg']);
%         ind_neg_all = fold_run_neg;        
        %%%%%%%%%%%%%%%%%%%%%%%
        optmodf = {};
        aa_value = [];
        bb_value = [];
        kk =1;
        for run=1:tot_run
            ind_pos = crossvalind('Kfold', size(target_data,1), 10);
            ind_neg = crossvalind('Kfold', size(outlier_data,1), 10);
            sup_vecf=[];
            
            for f=1:tot_fold
                test_posind = (ind_pos == f);
                train_posind = ~test_posind;
                test_negind = (ind_neg == f);
                train_negind = ~test_negind;
                
                test_pos=target_data(test_posind,:);
                train_pos=target_data(train_posind,:);
                test_neg=outlier_data(test_negind,:);
                train_neg=outlier_data(train_negind,:);
                
                train_data = train_pos(:,1:end-1);
                train_lbls = train_pos(:,end);
                test_data = cat(1, test_pos(:,1:end-1), test_neg(:,1:end-1));
                test_lbls = cat(1, test_pos(:,end), test_neg(:,end));
                val_data = train_neg(:, 1:end-1);
                val_lbls = train_neg(:,end);
                
                mmod.nor.dat = mean_and_std(train_data, 'true');
                train_data_m = normalize_data(train_data,mmod.nor.dat);
                
                temp_ind = 0;
                sup_vec=[];
                optmod = {};
                num_kern = 3;
                c_array = 10.^(-1:0.05:1);
                sig_array = power(2,-6:6);
%                 sig_array = 1;
                for sigm = 1:length(sig_array)
                    for k1=2:3
                        alp_all = [];
                        for c=1:length(c_array)
                            final = {['g' num2str(sig_array(sigm))],['p' num2str(k1)],'l'};
                            count=count+1;
                            [data_num first_class count]
                            if c==1
                                [model,model2]=create_model(train_data,train_lbls,final,c_array(c));
                                alp_all = [alp_all,model2.alpha];
                            else
                                [model,model2,aa,bb]=create_model2(train_data,train_lbls,final,c_array(c),c_array(c-1),alp_all(:,c-1));
                                alp_all = [alp_all,model2.alpha];
                                aa_value = [aa_value;aa];
                                bb_value = [bb_value;bb];
                            end
                            labeltr_GOCK = test_model(train_data,model,model2,final,c_array(c));
                            labelval_GOCK = test_model(val_data,model,model2,final,c_array(c));
                            labels_GOCK = test_model(test_data,model,model2,final,c_array(c));
                            
                            act_val_lbls = cat(1, train_pos(:,end), train_neg(:,end));
                            pred_val_lbls = [labeltr_GOCK; labelval_GOCK];
                            
                            temp_ind = temp_ind +1;
                            sup_vec1 = [];
                            for nk=1:num_kern
                                sup_vec1 = [sup_vec1; model.sup{1,nk}.ind];
                            end
                            sup_vec_curr = (length(unique(sup_vec1))/size(train_data,1))*100;
                            sup_vec = [sup_vec; sup_vec_curr];
                            optmod{temp_ind} = model;
                            
                            [accu(temp_ind) sens(temp_ind) spec(temp_ind) prec(temp_ind) rec(temp_ind) f11(temp_ind) gm(temp_ind)] = Evaluate(act_val_lbls,pred_val_lbls,1);
                            [accut(temp_ind) senst(temp_ind) spect(temp_ind) prect(temp_ind) rect(temp_ind) f11t(temp_ind) gmt(temp_ind)] = Evaluate(test_lbls,labels_GOCK,1);
                            
                            clear labels_GOCK labelval_GOCK labeltr_GOCK;
                        end
                        kk = kk+1;
                    end
                end
                %%%% Choose optimal parameters based on performance on validatin set
                [max_val opt_ind] = max(gm);
                [max_valt opt_indt] = max(gmt); %%% there is no use of opt_indt. just used for checking someting
                sup_vecf=[sup_vecf;sup_vec(opt_ind)];
                res.optmodf{run,f} = optmod{opt_ind};
                %%%% Training and Validation
                traccuracy(f)=accu(opt_ind); trsensitivity(f)=sens(opt_ind); trspecificity(f)=spec(opt_ind);
                trprecision(f)=prec(opt_ind); trrecall(f)=rec(opt_ind); trf1(f)=f11(opt_ind); trgmean(f)=gm(opt_ind);
                
                %%%% Testing
                accuracy(f)=accut(opt_ind); sensitivity(f)=senst(opt_ind); specificity(f)=spect(opt_ind);
                precision(f)=prect(opt_ind); recall(f)=rect(opt_ind); f1(f)=f11t(opt_ind); gmean(f)=gmt(opt_ind);
                
                clear test_posind train_posind test_negind train_negind test_pos...
                    train_pos test_neg train_neg train_data train_lbls test_data...
                    test_lbls Ktrain Ktest labels_GOCK gm
            end
            
            %%% For Training
            mtraccuracy(run) = mean(traccuracy)*100; mtrsensitivity(run) = mean(trsensitivity)*100; mtrspecificity(run) = mean(trspecificity)*100;
            mtrprecision(run) = mean(trprecision)*100; mtrrecall(run) = mean(trrecall)*100; mtrf1(run) = mean(trf1)*100; mtrgmean(run) = mean(trgmean)*100;
            train_result = [trsensitivity'*100 trspecificity'*100 trprecision'*100 trrecall'*100 trf1'*100 traccuracy'*100 trgmean'*100];
            mtrain_result = [mtrsensitivity(run) mtrspecificity(run) mtrprecision(run) mtrrecall(run) mtrf1(run) mtraccuracy(run) mtrgmean(run)];
            msv(run) = mean(sup_vecf);
            res.svfold(:,run) = sup_vecf';
            res.svmeanfold(run) = msv(run);
            res.trainfold(:,:,run) = train_result;
            res.trainmeanfold(run,:) = mtrain_result;
            clear traccuracy trsensitivity trspecificity trprecision trrecall trf1 trgmean train_result mtrain_result...
                ind_pos ind_neg;
            
            %%% For Testing
            maccuracy(run) = mean(accuracy)*100; msensitivity(run) = mean(sensitivity)*100; mspecificity(run) = mean(specificity)*100;
            mprecision(run) = mean(precision)*100; mrecall(run) = mean(recall)*100; mf1(run) = mean(f1)*100; mgmean(run) = mean(gmean)*100;
            test_result = [sensitivity'*100 specificity'*100 precision'*100 recall'*100 f1'*100 accuracy'*100 gmean'*100];
            mtest_result = [msensitivity(run) mspecificity(run) mprecision(run) mrecall(run) mf1(run) maccuracy(run) mgmean(run)];
            res.testfold(:,:,run) = test_result;
            res.testmeanfold(run,:) = mtest_result;
            clear ind_pos ind_neg accuracy sensitivity specificity precision recall f1 gmean test_result mtest_result;
        end
        
        %%% For Training
        %%%% Final performance evaluation over 5 runs
        mmtraccuracy = mean(mtraccuracy); mmtrsensitivity = mean(mtrsensitivity); mmtrspecificity = mean(mtrspecificity);
        mmtrprecision = mean(mtrprecision); mmtrrecall = mean(mtrrecall); mmtrf1 = mean(mtrf1); mmtrgmean = mean(mtrgmean);
        %%% For Testing
        %%%% Final performance evaluation over 5 runs
        mmaccuracy = mean(maccuracy); mmsensitivity = mean(msensitivity); mmspecificity = mean(mspecificity);
        mmprecision = mean(mprecision); mmrecall = mean(mrecall); mmf1 = mean(mf1); mmgmean = mean(mgmean);
        %%% For Training
        %%%% Standard Deviation over 5 runs
        std_mmtraccuracy = std(mtraccuracy); std_mmtrsensitivity = std(mtrsensitivity); std_mmtrspecificity = std(mtrspecificity);
        std_mmtrprecision = std(mtrprecision); std_mmtrrecall = std(mtrrecall); std_mmtrf1 = std(mtrf1); std_mmtrgmean = std(mtrgmean);
        %%% For Testing
        %%%% Standard Deviation over 5 runs
        std_mmaccuracy = std(maccuracy); std_mmsensitivity = std(msensitivity); std_mmspecificity = std(mspecificity);
        std_mmprecision = std(mprecision); std_mmrecall = std(mrecall); std_mmf1 = std(mf1); std_mmgmean = std(mgmean);
       
        res.aa = aa_value;
        res.bb = bb_value;
        toc
        mtrain_result = [mtrsensitivity' mtrspecificity' mtrprecision' mtrrecall' mtrf1' mtraccuracy' mtrgmean'];
        mmtrain_result = [mmtrsensitivity mmtrspecificity mmtrprecision mmtrrecall mmtrf1 mmtraccuracy mmtrgmean toc];
        res.trainmeanrun = mmtrain_result;
        res.svmeanrun=mean(msv);
        
        mtest_result = [msensitivity' mspecificity' mprecision' mrecall' mf1' maccuracy' mgmean'];
        mmtest_result = [mmsensitivity mmspecificity mmprecision mmrecall mmf1 mmaccuracy mmgmean toc];
        store_acc(first_class)=mmaccuracy;
        store_gmean(first_class)=mmgmean;
        res.testmeanrun = mmtest_result;
        
        mmtrainstd_result = [std_mmtrsensitivity std_mmtrspecificity std_mmtrprecision std_mmtrrecall std_mmtrf1 std_mmtraccuracy std_mmtrgmean toc];
        res.trainstd = mmtrainstd_result;
        res.svstd=std(msv);
        mmteststd_result = [std_mmsensitivity std_mmspecificity std_mmprecision std_mmrecall std_mmf1 std_mmaccuracy std_mmgmean toc];
        res.teststd = mmteststd_result;
        
        clear   mmtrain_result mmtrainstd_result mtrain_result mtest_result;
        res.performance = {'sensitivity','specificity', 'precision', 'recall', 'f1', 'accuracy', 'gmean','time'};
        res_all{data_num,first_class} = res;
        clear res;
    end
    save(sprintf('%s%d%s','res',data_num,'.mat'),'res_all')
end
save('gpl_result.mat','res_all');
