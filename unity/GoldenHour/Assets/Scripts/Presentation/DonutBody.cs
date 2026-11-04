using UnityEngine;

namespace GoldenHour.Presentation
{
    public sealed class DonutBody : MonoBehaviour
    {
        public int Id, Epoch;
        public bool Pending, InTray, Transferring;
        public float Age, StillTime, OutsideTime;
        public Rigidbody Body;
        public StandController Owner;
        public bool Reachable
        {
            get
            {
                if(!InTray||Pending||Transferring||!Body||Body.linearVelocity.sqrMagnitude>.20f)return false;
                var p=Owner.World.Tray.InverseTransformPoint(transform.position);
                return Mathf.Abs(p.x)<.23f&&Mathf.Abs(p.z)<.16f&&p.y>=0&&p.y<.17f;
            }
        }
        void OnDestroy(){if(Owner&&Owner.Food.TryGetValue(Id,out var current)&&current==this)Owner.Food.Remove(Id);}
        public void MakePhysical()
        {
            if (!Body) Body=gameObject.AddComponent<Rigidbody>();
            Body.mass=.025f; Body.linearDamping=.4f; Body.angularDamping=.8f;
            Body.collisionDetectionMode=CollisionDetectionMode.ContinuousDynamic;
            Body.interpolation=RigidbodyInterpolation.Interpolate;
            Body.isKinematic=false; Body.useGravity=true;
            var cols=GetComponents<SphereCollider>();
            if(cols.Length==0)
            {
                var physics=new PhysicsMaterial("Warm dough") { dynamicFriction=.42f,staticFriction=.48f,bounciness=.07f };
                for(int i=0;i<5;i++)
                {
                    var col=gameObject.AddComponent<SphereCollider>();col.radius=.013f;
                    float angle=i*Mathf.PI*2/5;col.center=new Vector3(Mathf.Cos(angle)*.017f,0,Mathf.Sin(angle)*.017f);col.sharedMaterial=physics;
                }
            }
            foreach(var col in GetComponents<Collider>())col.enabled=true;
            Transferring=false;
        }
        public void Hold()
        {
            Transferring=true; InTray=false;
            if(Body) { Body.isKinematic=true; Body.useGravity=false; }
            foreach(var c in GetComponents<Collider>())c.enabled=false;
        }
        void FixedUpdate()
        {
            if(!Owner||Transferring||!Body||Body.isKinematic)return;
            Age+=Time.fixedDeltaTime;
            Vector3 local=Owner.World.Tray.InverseTransformPoint(transform.position);
            bool contained=Mathf.Abs(local.x)<.235f && Mathf.Abs(local.z)<.17f && local.y>-.03f && local.y<.18f;
            if(contained) { OutsideTime=0; StillTime+=Time.fixedDeltaTime; }
            else { StillTime=0; OutsideTime+=Time.fixedDeltaTime; }
            if(Pending && StillTime>.22f && (Body.linearVelocity.sqrMagnitude<.25f||Age>3))
            {
                var result=Owner.Model.SettleDelivery(Id,true,Epoch); Pending=false; InTray=result.Accepted;
                if(!result.Accepted) Owner.MarkWaste(this);
            }
            if(Pending && (transform.position.y<.87f || Age>7))
            { Owner.Model.SettleDelivery(Id,false,Epoch); Pending=false; Owner.MarkWaste(this); }
            if(InTray && OutsideTime>.65f && (transform.position.y<.91f||Mathf.Abs(local.x)>.30f||Mathf.Abs(local.z)>.24f))
            { Owner.Model.SpillStock(new[]{Id}); InTray=false; Owner.MarkWaste(this); }
            if(transform.position.y<-2||Age>70&&!InTray&&!Pending) Destroy(gameObject);
        }
    }
}
