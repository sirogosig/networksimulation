int n_tags=0;
int beta =1; // Max number of paths to be considered vulnerable (Paramter for vulnerability measurement)
int numb_comm=0;

class Tag {
  Tree tree;
  Table logs;
  int id;
  float entropy=0.5;
  float vuln_prob;
  PVector suggested_new_cam;
  ArrayList <Tag> onehops; //One hop neighbours
  ArrayList <Tag> twohops; //two hop neighbours
  
  // timers
  int thinkTimer = 0;
   
  Tag (Tree tree) {
    this.tree=tree;
    this.id=n_tags;
    n_tags++;
    onehops = new ArrayList<Tag>();
    twohops = new ArrayList<Tag>();
    suggested_new_cam= new PVector(0,0);
    entropy=0.5;
    
    logs = new Table();
    logs.addColumn("id");
    logs.addColumn("species");
    logs.addColumn("day");
    logs.addColumn("hour");
    logs.addColumn("minute");
    
    thinkTimer = int(random(15));
  }
   
  void go () {
    increment();
    if(thinkTimer==0){
      getNeighbours();
      calcVulnProb();
    }
  }
   
  void draw () {
    noStroke();
    fill((int)((1-vuln_prob)*43), 255, 200); // Color between 0 (red) and 43 (yellow)
    
    ellipse(tree.pos.x, tree.pos.y, tag_diameter*(0.7+2*entropy), tag_diameter*(0.7+2*entropy));
     
    for (Tag tag : onehops) {
      stroke(150);
      line(this.tree.pos.x, this.tree.pos.y, tag.tree.pos.x, tag.tree.pos.y);
    }
    
    textSize(12);
    fill(255.0);
    text("ID: " + this.id, this.tree.pos.x+8, this.tree.pos.y-10);
    //text("1h: " + this.onehops.size(), this.tree.pos.x-28, this.tree.pos.y-20);
    //text("2h: " + this.twohops.size(), this.tree.pos.x-28, this.tree.pos.y-10);
    //text("vp: " + this.vuln_prob, this.tree.pos.x+8, this.tree.pos.y+8);
  }
  
  void calcVulnProb(){
    ArrayList <Tag> pathbeta= new ArrayList<Tag>();
    for(int i=0;i<twohops.size();i++){
      int numbpaths=0;
      for (int j=0;j<onehops.size();j++){
        if(ALmatch(twohops.get(i), onehops.get(j).onehops)) numbpaths++;
      }
      if(numbpaths==0) print("Error in numbpaths calculation");
      if(numbpaths<=beta && numbpaths>0) pathbeta.add(twohops.get(i));
    }
    if(this.onehops.size() == 0){
      vuln_prob =1;
      entropy=1;
    }
    else{
      this.vuln_prob=((float)pathbeta.size()/((float)(this.onehops.size()+this.twohops.size())));
      //this.entropy=calc_entropy();
      this.entropy=calc_entropy_unique(); //Another way of computing the entropy      
    }
    calc_snc(pathbeta);
  }
  
  void calc_snc(ArrayList<Tag> pathbeta){
    if(pathbeta.size()!=0){
      PVector final_pos=new PVector(0,0);      
      for(Tag tag : pathbeta){
        final_pos=PVector.add(final_pos,tag.tree.pos);
      }
      final_pos=PVector.div(final_pos, pathbeta.size()); // Barycenter of all 2-hops with max beta shortest path(s)
      // suggested_new_cam = i + (f-i)/2 : 
      suggested_new_cam= PVector.add(this.tree.pos, PVector.div(PVector.sub(final_pos,this.tree.pos),2));
    }
  }
  
  // The following calculates the entropy with all added twohops
  float calc_entropy(){
    int total_twohops=0;
    for (Tag tag : this.onehops) {
      if (tag.onehops.size()==0) return 1.0; // Do not calculate entropy if neighbouring nodes have not calculated their neighbours yet
      total_twohops+=tag.onehops.size()-1; // Minus one to avoid including ourself
    }
    if (total_twohops==0) return 1.0;

    float entropy=0;
    for (Tag tag : this.onehops){
      if(tag.onehops.size()>1){
        entropy+= ((float)tag.onehops.size()-1.0)/total_twohops*log(((float)tag.onehops.size()-1.0)/total_twohops); // Natural logarithm
      }    
    }
    return -entropy; // '-' in the Entropy formula
  }
  
  // The following calculates the entropy only with unique twohops
  float calc_entropy_unique(){
    float[] total_unique_twohops=new float[this.onehops.size()];
    for(int i=0;i<total_unique_twohops.length;i++) total_unique_twohops[i]=1.0; //initialise at 1 (themselves)
    
    //Share two-hops between one-hops
    for (int i=0;i< this.twohops.size();i++){
      Tag twohop=this.twohops.get(i);
      int links=0;
      for(int j=0;j<onehops.size();j++){
        Tag onehop=onehops.get(j);
        if(ALmatch(twohop,onehop.onehops)){
          links++;
        }
      }
      for(int j=0;j<onehops.size();j++){
        Tag onehop=onehops.get(j);
        if(ALmatch(twohop,onehop.onehops)){
          total_unique_twohops[j]+=1.0/links;
        }
      }
    }
    
    //float sum_total_unique_twohops=0;
    //for(int i=0;i<total_unique_twohops.length;i++){
    //  sum_total_unique_twohops+=total_unique_twohops[i];
    //}
    //print(this.id + " : " + sum_total_unique_twohops + "  " +this.twohops.size() + '\n');

    // Merge connected one-hops
    for(int i=0;i<this.onehops.size();i++){
      if(total_unique_twohops[i]>=1) total_unique_twohops=merge(total_unique_twohops,i,i);
    }
    
    int total=this.twohops.size()+this.onehops.size();
    float entropy=0.0;
    for (int i=0; i<total_unique_twohops.length;i++){
      print(total_unique_twohops[i]);
      if(total_unique_twohops[i]>0){
        entropy+=((float)total_unique_twohops[i])/total*log(((float)total_unique_twohops[i])/total);
      }  
    }
    return abs(entropy); // '-' in the Entropy formula
  }
  
  // Function that merges all linked nodes into the node at redirect_index
  float[] merge(float[] weights, int redirect_index,int emitter_index){
    for(int i=0;i<onehops.size();i++){
      if(i==emitter_index || i==redirect_index) continue;
      if(ALmatch(onehops.get(i),onehops.get(emitter_index).onehops) && weights[i]>0){
        weights[redirect_index]+=weights[i];
        weights[i]=-redirect_index;
        weights=merge(weights,redirect_index,i);
      }
    }
    return weights;
  }
  
  void getNeighbours () {
    ArrayList<Tag> onehops_ = new ArrayList<Tag>();
    for (int i =0; i < tags.size(); i++) {
      Tag tag = tags.get(i);
      if (tag == this) continue;
      if (PVector.dist(tag.tree.pos, this.tree.pos)<commRadius) {
        onehops_.add(tag);
      }
    }
    this.onehops = onehops_;
    
    ArrayList<Tag> twohops_ = new ArrayList<Tag>();
    for (int i=0;i< this.onehops.size();i++){
      Tag onehop=this.onehops.get(i);
      for(int j=0;j<onehop.onehops.size();j++){
        Tag tag=onehop.onehops.get(j);
        if (tag==this) continue;
        if(!ALmatch(tag,twohops_) && !ALmatch(tag,this.onehops)){
          twohops_.add(onehop.onehops.get(j)); // My twohopss are my onehopss' onehopss
        }
      }
    }
    this.twohops = twohops_;
  }
  
  void addLog(int id, String species, int day, int hour, int minute){
    TableRow newRow = logs.addRow();
    newRow.setInt("id", id);
    newRow.setString("species", species);
    newRow.setInt("day", day);
    newRow.setInt("hour", hour);
    newRow.setInt("minute", minute);
    numb_comm+=5; // Count the communication that was made (5 x uint8);
  }
  
  // update timer
  void increment () {
    thinkTimer = (thinkTimer + 1) % 15; // The thinkTimer is between 0 and 14
  }
}


// Function that returns if a Tag had already been included in an ArrayList
boolean ALmatch(Tag tag_, ArrayList<Tag> list){
  for(Tag tag : list){
    if (tag_.equals(tag)) return true;
  }
  return false;
}
